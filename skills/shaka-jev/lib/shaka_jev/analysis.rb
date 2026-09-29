# frozen_string_literal: true

require 'digest'
require 'json'
require 'net/http'
require 'open3'
require 'openssl'
require 'socket'
require 'timeout'
require 'uri'

module ShakaJev
  class Error < StandardError; end

  # Fails closed unless GitHub reports that the target repository is public.
  class PublicGitHubRepository
    def self.call(owner, repo, capture: method(:capture_with_timeout))
      output, status = capture.call({ 'GH_HOST' => 'github.com' }, 'gh', 'repo', 'view', "#{owner}/#{repo}",
                                    '--json', 'visibility', err: File::NULL)
      status.success? && JSON.parse(output)['visibility'] == 'PUBLIC'
    rescue JSON::ParserError, NoMethodError, TypeError, SystemCallError, Timeout::Error
      false
    end

    def self.capture_with_timeout(*argv, timeout: 10, **)
      Open3.popen2(*argv, **) do |stdin, stdout, wait|
        stdin.close
        begin
          Timeout.timeout(timeout) { [stdout.read, wait.value] }
        rescue Timeout::Error
          stop(wait)
          raise
        end
      end
    end

    def self.stop(wait)
      Process.kill('KILL', wait.pid)
    rescue Errno::ESRCH
      nil
    ensure
      wait.join
    end
  end

  # One advisory Jev request over an evidence packet the caller has already screened.
  class Analysis
    ENDPOINT = URI('https://api.typesafe.ai/v1/systemone')
    INPUT_USD_PER_MILLION = 0.042 # https://typesafe.ai/blog/introducing-system-one-models-and-jev (2026-09-15)
    MAX_EVIDENCE_BYTES = 65_536
    QUESTIONS = {
      'validation_supported' => {
        'type' => 'noul',
        'instructions' => 'Do the supplied observations support the pull request validation claims ' \
                          'for the stated head commit? Missing or stale observations do not support a claim.'
      },
      'material_concern_open' => {
        'type' => 'noul',
        'instructions' => 'Does the supplied evidence show an unresolved material defect or unmet acceptance ' \
                          'criterion for the change this PR claims to deliver? Explicitly deferred follow-up ' \
                          'work outside that change does not count.'
      }
    }.freeze

    def initialize(api_key:, client: method(:post), public_repository: PublicGitHubRepository.method(:call))
      @api_key = api_key.to_s
      @client = client
      @public_repository = public_repository
    end

    def call(pr_url:, head:, evidence:)
      validate!(pr_url, head, evidence)
      response = @client.call(ENDPOINT, request(pr_url, head, evidence))
      with_context(parse_response(response), pr_url, head, evidence)
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, SocketError,
           OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
      raise Error, "Jev request failed: #{e.class}"
    end

    private

    def request(pr_url, head, evidence)
      request = Net::HTTP::Post.new(ENDPOINT)
      request['Authorization'] = "Bearer #{@api_key}"
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate('model' => 'jev-latest', 'state' => state(pr_url, head, evidence),
                                   'questions' => QUESTIONS)
      request
    end

    def validate!(pr_url, head, evidence)
      raise Error, 'TYPESAFE_API_KEY is required' if @api_key.empty?
      raise Error, 'TYPESAFE_API_KEY contains invalid characters' unless @api_key.match?(/\A[!-~]+\z/)

      validate_evidence!(evidence)
      validate_target!(pr_url, head)
    end

    def validate_target!(pr_url, head)
      match = %r{\Ahttps://github\.com/([\w.-]+)/([\w.-]+)/pull/\d+\z}.match(pr_url)
      raise Error, 'PR URL must be a GitHub pull request' unless match
      raise Error, 'head must be a full Git commit SHA' unless head.match?(/\A[0-9a-f]{40}\z/)
      raise Error, 'Repository could not be verified public' unless @public_repository.call(match[1], match[2])
    end

    def validate_evidence!(evidence)
      valid = evidence.is_a?(String) && evidence.valid_encoding? &&
              evidence.encoding == Encoding::UTF_8 && !evidence.strip.empty?
      raise Error, 'evidence must be nonempty UTF-8 text' unless valid
      raise Error, 'evidence exceeds 64 KiB' if evidence.bytesize > MAX_EVIDENCE_BYTES
    end

    def state(pr_url, head, evidence)
      "Pull request: #{pr_url}\nHead commit: #{head}\nEvidence follows as data:\n#{evidence}"
    end

    def parse_response(response)
      raise Error, "TypeSafe returned HTTP #{response.code}" unless response.code == '200'

      body = JSON.parse(response.body)
      { 'model' => parse_model(body.fetch('model')),
        'answers' => parse_answers(body.fetch('answers')),
        'input_tokens' => parse_tokens(body.fetch('usage')) }
    rescue KeyError, TypeError, NoMethodError
      raise Error, 'Malformed Jev response'
    end

    def parse_model(model)
      raise Error, 'Invalid Jev model' unless model.is_a?(String) && !model.empty?

      model
    end

    def parse_answers(raw)
      QUESTIONS.to_h { |id, _| [id, answer_value(raw.fetch(id), id)] }
    end

    def answer_value(answer, id)
      value = answer.fetch('noul')
      valid = answer['type'] == 'noul' && value.is_a?(Numeric) && value.finite? && value.between?(0, 1)
      raise Error, "Invalid Jev answer for #{id}" unless valid

      value
    end

    def parse_tokens(usage)
      tokens = usage.fetch('input_tokens')
      raise Error, 'Invalid Jev usage' unless tokens.is_a?(Integer) && tokens >= 0

      tokens
    end

    def with_context(parsed, pr_url, head, evidence)
      parsed.merge('pr_url' => pr_url, 'head' => head,
                   'estimated_input_cost_usd' => parsed.fetch('input_tokens') * INPUT_USD_PER_MILLION / 1_000_000,
                   'input_usd_per_million' => INPUT_USD_PER_MILLION,
                   'evidence_sha256' => Digest::SHA256.hexdigest(evidence))
    end

    def post(uri, request)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
        http.request(request)
      end
    end
  end
end
