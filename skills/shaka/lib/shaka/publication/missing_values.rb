# frozen_string_literal: true

module Shaka
  # Explains, under Shaka metrics, a value the description could not show and how the next update fills it.
  module MissingValues
    SUMMARY = 'Missing values'
    # Watcher updates look for this to tell a body that carries the note from one published before it existed.
    HEADING = "<summary>#{SUMMARY}</summary>".freeze
    COST_LINE = 'the cost line shows no time from task start to ready or merge'
    TIMINGS = 'Timings shows Prompt to CI as not recorded'
    TO_FILL = 'To fill it, the agent passes the original request as `codex_task_start` or its timestamp as ' \
              '`task_started_at`.'

    # The usage archive reads the full line back from here to sign its comments with all four fields.
    WRITER = /^- \*\*Writer identity\*\* is `(🤖 [^`\r\n·]+(?: · [^`\r\n·]+){3})`/

    module_function

    def detail(throughput, content, timings:)
      items = [task_start(throughput, timings), writer(content)].compact
      { 'summary' => SUMMARY, 'body' => items.join("\n") } unless items.empty?
    end

    # Timings is named only when the description renders that section.
    def task_start(throughput, timings)
      return if ThroughputStats.task_started?(throughput)

      effects = timings ? "#{COST_LINE}, and #{TIMINGS}" : COST_LINE
      "- **Task start** was not recorded, so #{effects}. #{TO_FILL}"
    end

    # The first line drops unread fields; this keeps each marked UNKNOWN, with the publisher's reason.
    def writer(content)
      return unless PublicationText.unknown_identity?(content['identity'])

      note = content['publisher_note']
      ["- **Writer identity** is `#{PublicationText.identity(content['identity'])}`; the first line shows only " \
       'the fields that were read.', *(PublicationText.single_line(note, 'publisher note') if note)].join(' ')
    end
  end
end
