# frozen_string_literal: true

require_relative '../github'
require_relative '../publication/usage_details'
require_relative '../public_comments/bounded_list'
require_relative 'journal_records'
require_relative 'journal_summary'
require_relative 'publisher_attribution'

module Shaka
  # Reads the publishing host's last observed settings, separate from the contributor's settings.
  module UsageJournalWriter
    module_function

    def identity
      observed = PublisherAttribution.prepare({})['identity']
      return native_identity unless observed

      PublicationText.identity(observed.merge('provider' => native_settings.first))
    rescue StandardError
      PublicationText.identity({})
    end

    def native_identity
      provider, model, routed, effort = native_settings
      PublicationText.identity('agent' => Usage::READERS.fetch(Usage.detected_host)::HOST, 'provider' => provider,
                               'model' => routed == 'UNKNOWN' ? model : routed || model, 'effort' => effort)
    end

    def native_settings
      require_relative 'usage'
      reader = Usage::READERS.fetch(Usage.detected_host)
      reader.new(reader.discover, [], all_turns: false).responses.values.last.to_h.fetch('configuration', [])
    end
  end

  # Appends immutable snapshots. Concurrent publishers never replace a shared PR body.
  class UsageJournal
    MARK = '<!-- shaka:usage-journal:v1 -->'
    EVENTS = %w[commit comment testing review handoff checkpoint finish].freeze
    MAX_BODY = 60_000

    def initialize(github, identity: nil)
      @github = github
      @writers = {}
      @supplied_identity = identity
    end

    def publish(records, event:)
      raise Error, "Usage event must be one of #{EVENTS.join(', ')}." unless EVENTS.include?(event)

      fresh = unpublished(records)
      return [] if fresh.empty?

      # Preflight every chunk. Retries append only records absent from confirmed earlier writes.
      bodies = chunks(fresh).map { |chunk| body(chunk, event) }
      bodies.each { |text| @github.verify_rendering(text) }
      bodies.map { |text| append(text) }
    end

    def append(text)
      created = @github.api(comment_path, method: 'POST', fields: { body: text })
      raise Error, 'Stored usage snapshot differs; inspect the PR before retrying.' unless created['body'] == text
      raise Error, 'This account lacks write access, so collection will ignore its usage comments.' unless
        writer?(created)

      created.slice('id', 'html_url')
    end

    def collect
      { 'note' => 'Durable PR snapshots; each native response is counted once. Native usage remains PARTIAL.',
        'records' => UsageJournalSummary.compact(UsageJournalRecords.combine(stored_records)) }
    end

    private

    def unpublished(records)
      normalized = UsageJournalRecords.parse(snapshot(UsageJournalRecords.combine(records)))
      previous = UsageJournalRecords.combine(stored_records)
      UsageJournalRecords.combine(previous + normalized).reject { |record| previous.include?(record) }
    end

    def stored_records
      comments.flat_map do |comment|
        next [] unless comment['body'].to_s.start_with?("#{MARK}\n") && writer?(comment)

        parsed(comment)
      end
    end

    # One unreadable comment stops every read, so name it: its owner has to repair or delete it.
    def parsed(comment)
      UsageJournalRecords.parse(comment['body'])
    rescue Error => e
      raise Error, "#{e.message} Comment: #{comment['html_url'] || comment['id']}."
    end

    def comment_path = "repos/#{@github.repository}/issues/#{@github.number}/comments"

    def comments
      PublicComments::BoundedList.new(@github, max_pages: 100, label: 'Usage journal').call(comment_path)
    end

    # Comment authors need current write access. A marker from an outside commenter is not evidence.
    def writer?(comment)
      login = comment.dig('user', 'login')
      return false unless login.is_a?(String) && login.match?(/\A[A-Za-z0-9][A-Za-z0-9-]{0,38}(?:\[bot\])?\z/)

      @writers.fetch(login) { @writers[login] = write_permission?(login) }
    end

    # An account GitHub cannot resolve holds no verified access; any other failure stops the read,
    # because dropping a real writer's comments would undercount silently.
    def write_permission?(login)
      result = @github.api("repos/#{@github.repository}/collaborators/#{login}/permission")
      result.dig('user', 'login').to_s.casecmp?(login) && %w[admin maintain write].include?(result['permission'])
    rescue Error => e
      raise unless e.http_status == 404

      false
    end

    def chunks(records)
      raise Error, 'Usage journal requires nonempty records.' unless records.is_a?(Array) && !records.empty?

      records.each_with_object([[]]) do |record, grouped|
        body([record], 'checkpoint') # Check even a single record fits, before publication.
        grouped << [] if grouped.last.any? && body_length(grouped.last + [record]) > MAX_BODY
        grouped.last << record
      end
    end

    def body_length(records) = text(records, 'checkpoint').length

    # Read only when writing: a receiving host collects without the earlier machine's transcripts.
    def identity = @identity ||= @supplied_identity || UsageJournalWriter.identity

    def text(records, event) = "#{MARK}\n#{identity}\n\nUsage snapshot: #{event}.\n\n#{snapshot(records)}"

    def body(records, event)
      text = text(records, event)
      raise Error, 'Usage record exceeds the comment limit; narrow the selected source.' if text.length > MAX_BODY

      text
    end

    def snapshot(records) = [render(records), UsageJournalWholeTask.line(records)].compact.join("\n\n")

    def render(records)
      detail = UsageDetails.new('note' => '', 'records' => records).detail
      "<details>\n<summary>#{detail['summary']}</summary>\n\n#{detail['body']}\n\n</details>"
    end
  end
end
