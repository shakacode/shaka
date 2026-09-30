# frozen_string_literal: true

require_relative '../error'

module Shaka
  class WorkflowConfiguration
    # Pages GitHub name lists and keeps only names. Variable values never leave the response hash.
    class Pages
      NAME = /\A[A-Za-z_][A-Za-z0-9_]*\z/
      PAGE_SIZE = 100
      MAX_PAGES = 30

      def initialize(github)
        @github = github
      end

      def list(path) = arrays(path) { |batch| batch }

      def object(path) = read_object(path)

      def content(path)
        @github.api(path)
      rescue Error => e
        return :denied if e.http_status == 403
        return :unreadable if e.http_status == 404

        raise
      end

      def decode_text(body)
        return :unreadable unless body.is_a?(Hash) && body['encoding'] == 'base64' && body['content'].is_a?(String)

        text = body['content'].unpack1('m').dup.force_encoding(Encoding::UTF_8)
        text.valid_encoding? ? text : :unreadable
      end

      def named(path, key)
        arrays_of(path) { |body| names_from(body, key) }
      end

      private

      def arrays(path)
        collected = []
        (1..MAX_PAGES).each do |page|
          batch = read_list("#{path}?per_page=#{PAGE_SIZE}&page=#{page}")
          return [:denied, collected] if batch == :denied
          raise Error, 'GitHub list page is malformed.' unless batch.is_a?(Array) && batch.size <= PAGE_SIZE

          collected.concat(yield(batch))
          return [:ok, collected] if batch.size < PAGE_SIZE
        end
        [:truncated, collected]
      end

      def arrays_of(path)
        collected = []
        (1..MAX_PAGES).each do |page|
          body = read_object("#{path}?per_page=#{PAGE_SIZE}&page=#{page}")
          return [:denied, collected] if body == :denied

          batch = yield body
          collected.concat(batch)
          return [:ok, collected] if batch.size < PAGE_SIZE
        end
        [:truncated, collected]
      end

      def names_from(body, key) = list_rows(body, key).map { |row| name_of(row) }

      def list_rows(body, key)
        rows = body[key] if body.is_a?(Hash)
        raise Error, 'GitHub name list is malformed.' unless rows.is_a?(Array) && rows.size <= PAGE_SIZE

        rows
      end

      def name_of(row)
        name = row['name'] if row.is_a?(Hash)
        raise Error, 'GitHub name list is malformed.' unless name.is_a?(String) && name.match?(NAME)

        name
      end

      def read_object(path) = rescue_denied { @github.api(path) }
      def read_list(path) = rescue_denied { @github.api_list(path) }

      def rescue_denied
        yield
      rescue Error => e
        return :denied if [403, 404].include?(e.http_status)

        raise
      end
    end
  end
end
