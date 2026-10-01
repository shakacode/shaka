# frozen_string_literal: true

require 'fileutils'
require 'json'
require_relative '../error'
require_relative '../github'
require_relative '../publication/usage_details'
require_relative 'cursor_usage'
require_relative 'cursor_usage_store'
require_relative 'usage_records'

module Shaka
  # Renders the usage details block the stop hook swaps into a published description.
  module UsageDetailsBlock
    def self.markdown(spec)
      rendered = UsageDetails.new(spec).detail
      summary = PublicationText.summary_text(rendered['summary'], 'details summary')
      "<details>\n<summary>#{summary}</summary>\n\n#{rendered['body']}\n\n</details>"
    end
  end

  # Stores the Cursor selection and pull request until the stop hook writes the record.
  class CursorUsageRequest
    MAX_SELECTIONS = 20

    def self.remember(options, inferred:)
      id = CursorUsageRefresh.conversation_id
      return unless id && options[:host] == 'cursor'

      update(id) { |request| add_selection(request, selection_from(options, inferred)) }
    rescue Error, SystemCallError, JSON::ParserError
      nil
    end

    def self.bind(repository, number, usage)
      id = CursorUsageRefresh.conversation_id
      return unless id && cursor_usage?(usage)

      update(id) { |request| request['publication'] = publication(repository, number, usage) }
      'bound'
    rescue Error, SystemCallError, JSON::ParserError
      nil
    end

    def self.clear_publication(id)
      update(id) { |request| request.delete('publication') }
    rescue Error, SystemCallError, JSON::ParserError
      nil
    end

    def self.pin_generation(id, generation)
      pinned = nil
      update(id) { |request| pinned = pin(request, generation) }
      pinned
    rescue Error, SystemCallError, JSON::ParserError
      nil
    end

    def self.read(id)
      path = path_for(id)
      return unless File.file?(path)

      parsed = JSON.parse(File.read(path, encoding: 'UTF-8'))
      parsed if parsed.is_a?(Hash)
    rescue JSON::ParserError, SystemCallError
      nil
    end

    class << self
      private

      def pin(request, generation)
        publication = request['publication']
        return unless publication.is_a?(Hash) && generation.is_a?(String)
        return unless generation.match?(CursorUsageStore::IDENTITY)

        publication['generation'] ||= generation
      end

      def publication(repository, number, usage)
        unless repository.is_a?(String) && repository.match?(%r{\A[\w.-]+/[\w.-]+\z})
          raise Error, 'Cursor usage refresh expected OWNER/REPO.'
        end
        raise Error, 'Cursor usage refresh expected a pull request number.' unless number.to_s.match?(/\A[1-9]\d*\z/)

        { 'repository' => repository, 'number' => number.to_i, 'usage' => stored_usage(usage) }
      end

      def stored_usage(usage)
        kept = usage.slice('note', 'records', 'carried')
        raise Error, 'Cursor usage refresh expected usage records.' unless kept['records'].is_a?(Array)

        kept
      end

      def cursor_usage?(usage)
        usage.is_a?(Hash) && Array(usage['records']).any? { |record| record.is_a?(Hash) && record['host'] == 'cursor' }
      end

      def add_selection(request, selection)
        request['selections'] = Array(request['selections']).reject { |item| item == selection }
        request['selections'] << selection
        request['selections'] = request['selections'].last(MAX_SELECTIONS)
      end

      def selection_from(options, inferred)
        { 'commit' => options[:commit], 'contribution' => options[:contribution], 'inferred' => inferred == true,
          'files' => inferred ? [] : Array(options[:files]), 'turns' => Array(options[:turns]),
          'all_turns' => options[:all_turns] == true, 'since_time' => options[:since_time] }.compact
      end

      def update(id)
        path = path_for(id)
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, File::RDWR | File::CREAT, 0o600) do |file|
          file.flock(File::LOCK_EX)
          request = load_request(file.read, id)
          yield request
          file.rewind
          file.truncate(0)
          file.write("#{JSON.generate(request)}\n")
        end
      end

      def load_request(text, id)
        parsed = text.strip.empty? ? nil : JSON.parse(text)
        request = parsed.is_a?(Hash) && parsed['conversation_id'] == id ? parsed : { 'conversation_id' => id }
        request['selections'] ||= []
        request
      rescue JSON::ParserError
        { 'conversation_id' => id, 'selections' => [] }
      end

      def path_for(id) = File.join(CursorUsageStore.home, 'pending', "#{id}.json")
    end
  end

  # Replays only selections that name a Cursor record already on the published description.
  class CursorUsageReplay
    def self.documents(request, conversation, generation)
      records = Array(request.dig('publication', 'usage', 'records'))
      Array(request['selections']).filter_map do |selection|
        read(selection, conversation, generation) if selected(selection, records)
      end
    end

    class << self
      private

      def selected(selection, records)
        selection.is_a?(Hash) && records.any? { |record| same_work?(record, selection) }
      end

      def same_work?(record, selection)
        record.is_a?(Hash) && record['host'] == 'cursor' &&
          record['contribution'] == selection['contribution'] &&
          Array(record['commits']).include?(selection['commit'])
      end

      def read(selection, conversation, generation)
        require_relative 'usage'
        Usage.new(options(selection, conversation, generation)).json_document
      rescue Error
        nil
      end

      def options(selection, conversation, generation)
        { files: files(selection, conversation), turns: turns(selection, generation), host: 'cursor', format: 'json',
          commit: selection['commit'], contribution: selection['contribution'],
          all_turns: selection['all_turns'] == true, since_time: selection['since_time'] }.compact
      end

      def turns(selection, generation)
        listed = Array(selection['turns'])
        return listed unless listed.empty? && selection['all_turns'] != true && !selection['since_time']

        [generation].compact
      end

      def files(selection, conversation)
        return Array(selection['files']) unless selection['inferred']

        [File.join(CursorUsageStore.home, "#{conversation}.jsonl")]
      end
    end
  end

  # Fills a published Cursor usage row once the stop hook has written the working turn.
  class CursorUsageRefresh
    OPENING = "<details>\n<summary>#{UsageDetails::SUMMARY}".freeze

    def self.remember(options, inferred:) = CursorUsageRequest.remember(options, inferred:)
    def self.bind(repository, number, usage) = CursorUsageRequest.bind(repository, number, usage)

    def self.after_write(record)
      id = record['conversation_id']
      request = CursorUsageRequest.read(id)
      return unless request && request['conversation_id'] == id

      generation = CursorUsageRequest.pin_generation(id, record['generation_id'])
      usage = refreshed_usage(request, id, generation)
      return unless usage

      publish(request['publication'], usage)
      CursorUsageRequest.clear_publication(id)
    rescue StandardError
      nil
    end

    def self.conversation_id
      id = ENV.fetch('CURSOR_CONVERSATION_ID', nil)
      id if id.is_a?(String) && id.match?(CursorUsageStore::IDENTITY)
    end

    class << self
      private

      def refreshed_usage(request, conversation, generation)
        publication = request['publication']
        return unless publication.is_a?(Hash) && publication['usage'].is_a?(Hash)

        documents = CursorUsageReplay.documents(request, conversation, generation)
        merge_usage(publication['usage'], documents) unless documents.empty?
      end

      def merge_usage(usage, documents)
        records = Array(usage['records']).map(&:dup)
        original = records.map { |record| JSON.generate(record) }
        documents.each { |document| records = fold(records, document['record']) }
        return if records.map { |record| JSON.generate(record) } == original

        usage.merge('records' => records, 'note' => note_for(usage, documents))
      end

      def fold(records, incoming)
        fields = UsageRecordCarry.identity(incoming)
        return records unless fields && readable?(incoming)

        fresh = [fields]
        kept = records.reject { |old| drop_old?(old, fresh) }
        kept.any? { |old| UsageRecordCarry.identity(old) == fields } ? kept : kept + [incoming]
      end

      def readable?(record)
        record.is_a?(Hash) && record['complete'] == true && Array(record['responses']).any?
      end

      def drop_old?(old, fresh)
        fields = UsageRecordCarry.identity(old)
        fields && (UsageRecordCarry.read_nothing_covered?(fields, fresh) || UsageRecords.superseded?(fields, fresh))
      end

      def note_for(usage, documents)
        note = usage['note']
        return note unless note.to_s.include?(CursorUsage::UNAVAILABLE)

        documents.filter_map { |document| document['note'] if readable?(document['record']) }.last || note
      end

      def publish(publication, usage)
        github = GitHub.new(publication['repository'], publication['number'])
        github.description { |pull| refreshed_region(pull['body'], usage_for(pull, usage)) }
      end

      def usage_for(pull, usage)
        fresh = usage.merge('records' => cursor_records(usage))
        updated, = UsageRecords.carry_from({ 'usage' => fresh.except('carried') }, pull)
        updated.fetch('usage')
      end

      def cursor_records(usage)
        Array(usage['records']).select { |record| record.is_a?(Hash) && record['host'] == 'cursor' }
      end

      def refreshed_region(body, usage)
        region = Publishing.managed_region(body)
        raise Error, 'Cursor usage refresh found no managed description.' unless region

        updated = replace_block(region, UsageDetailsBlock.markdown(usage))
        raise Error, 'Cursor usage refresh found no usage section.' unless updated

        updated
      end

      def replace_block(region, block)
        start = region.index(OPENING)
        return unless start && region.index(OPENING, start + OPENING.length).nil?

        finish = details_end(region, start)
        "#{region[0...start]}#{block}#{region[finish..]}" if finish
      end

      def details_end(text, start)
        depth = 0
        index = start
        while (match = text.match(%r{<details>|</details>}, index))
          depth += match[0] == '<details>' ? 1 : -1
          return match.end(0) if depth.zero?

          index = match.end(0)
        end
        nil
      end
    end
  end
end
