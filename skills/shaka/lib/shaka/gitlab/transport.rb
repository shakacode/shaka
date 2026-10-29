# frozen_string_literal: true

module Shaka
  class GitLab
    # Keeps API failures and incomplete lists distinct from readable native evidence.
    module Transport
      PAGE_SIZE = 100
      MAX_PAGES = 100
      Response = Data.define(:value, :next_page)

      def api(path, method: 'GET', fields: {}, expected: Hash)
        validate_path(path)
        raise Error, 'Invalid GitLab HTTP method.' unless %w[GET POST PUT PATCH DELETE].include?(method)

        if method == 'GET' && !fields.empty?
          path = "#{path}?#{URI.encode_www_form(fields)}"
          fields = {}
        end
        request(path, method:, fields:, expected:).value
      end

      def api_list(path, fields: {})
        validate_path(path)
        validate_filters(fields)
        results = []
        (1..MAX_PAGES).each do |page|
          response = request(page_path(path, fields, page), expected: Array)
          validate_records(response.value)
          results.concat(response.value)
          return results if last_page?(response, page)
        end
        raise Error, 'GitLab pagination limit reached; evidence is incomplete.'
      end

      private

      def page_path(path, fields, page)
        "#{path}?#{URI.encode_www_form(fields.merge('per_page' => PAGE_SIZE, 'page' => page))}"
      end

      def validate_filters(fields)
        return if fields.is_a?(Hash) && !fields.keys.map(&:to_s).intersect?(%w[page per_page])

        raise Error, 'GitLab list filters must be a mapping without pagination overrides.'
      end

      def validate_records(records)
        return if records.length <= PAGE_SIZE && records.all?(Hash)

        raise Error, 'GitLab list returned malformed records.'
      end

      def last_page?(response, page)
        following = response.next_page
        return response.value.length < PAGE_SIZE if following.nil?
        return true if following.empty?
        return false if following == (page + 1).to_s

        raise Error, 'GitLab returned an invalid next page; evidence is incomplete.'
      end

      def validate_path(path)
        raise Error, 'Expected a relative ASCII GitLab API endpoint.' unless endpoint_text?(path)

        decoded = URI.decode_www_form_component(path)
        valid = decoded.valid_encoding? && !decoded.match?(/[[:cntrl:]]/) &&
                !decoded.split('/', -1).intersect?(['', '.', '..'])
        raise Error, 'Expected a relative GitLab API endpoint without query parameters.' unless valid
      rescue ArgumentError
        raise Error, 'Invalid GitLab API endpoint encoding.'
      end

      def endpoint_text?(path)
        path.is_a?(String) && path.ascii_only? && path.match?(%r{\A[A-Za-z][A-Za-z0-9._~/%-]*\z})
      end

      def request(path, method: 'GET', fields: {}, expected: Hash)
        argv = ['glab', 'api', '--hostname', @host, path, '--method', method, '--include', '--input', '-']
        stdout, _stderr, status = @runner.call(argv, stdin_data: JSON.generate(fields))
        headers, body = response_body(stdout, status)
        following = headers[/^x-next-page:[ \t]*([^\r\n]*)/i, 1]&.strip
        Response.new(value: parse_json(body, expected), next_page: following)
      rescue Errno::ENOENT
        raise Error, 'GitLab CLI is unavailable; install glab and authenticate.'
      end

      def response_body(stdout, status)
        headers, body = utf8(stdout).split(/\r?\n\r?\n/, 2)
        http_status = headers&.[](%r{\AHTTP/\S+ (\d{3})\b}, 1)&.to_i
        raise request_failure(status, http_status) unless status.exitstatus&.zero? && http_status &&
                                                          (200..299).cover?(http_status)

        [headers, body]
      end

      def request_failure(status, http_status)
        detail = http_status ? ", HTTP #{http_status}" : ''
        code = status.exitstatus || 'unavailable'
        Error.new("GitLab API request failed (exit #{code}#{detail}).", http_status:)
      end

      def parse_json(body, expected)
        return nil if body.to_s.empty? && expected == NilClass

        result = JSON.parse(body.to_s)
        raise Error, 'GitLab API response has an unexpected type.' unless result.is_a?(expected)

        result
      rescue JSON::ParserError
        raise Error, 'GitLab returned invalid JSON.'
      end

      def utf8(value)
        raise Error, 'Expected UTF-8 GitLab response.' unless value.is_a?(String)

        text = value.dup.force_encoding(Encoding::UTF_8)
        raise Error, 'Invalid UTF-8 GitLab response.' unless text.valid_encoding?

        text
      end
    end
  end
end
