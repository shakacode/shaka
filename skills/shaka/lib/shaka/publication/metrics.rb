# frozen_string_literal: true

module Shaka
  # Groups workflow facts separately from a pull request's own evidence.
  module PublicationMetrics
    # One fold holds everything Shaka records about the work, so the section stays one line until a reader digs.
    DETAILS = '🤙 Shaka details'

    private

    # Only helper-owned metadata belongs here; caller-supplied details remain with the change's evidence.
    def metrics
      usage_detail = UsageDetails.new(@content['usage']).detail
      ['## Shaka metrics', "#{UsageEstimate.markdown(usage_detail)}#{ThroughputStats.took(throughput)}",
       details_block('summary' => DETAILS, 'body' => records(usage_detail).join("\n\n"))]
    end

    # The chat link leads because it is the record a returning maintainer reaches for most.
    def records(usage_detail)
      blocks = [*missing_values, details_block(usage_detail), *timings,
                provenance, details_block(@settings.detail), *skills_used, *task_history, *wip]
      [*chat_link, *blocks]
    end

    # GitHub drops links to app addresses such as claude:// and codex://, so the address goes in a
    # code block, whose copy button takes it in one click. A chat opens only on the machine that holds it,
    # so the label names that machine in a code span when the owner's alias is known.
    def chat_link
      address = wip_note&.chat_link
      return [] unless address

      machine = wip_note.machine
      ["**Chat link#{" on `#{machine}`" if machine}:**\n\n```text\n#{address}\n```"]
    end

    # The note is optional because it disappears once GitHub confirms the outcome.
    def wip = wip_note ? [details_block(wip_note.detail)] : []

    def wip_note
      return unless (spec = @content['wip'])

      info = { environment: @environment, disclosure: @content['wip_disclosure'], pull: @pull, host_name: @host_name }
      @wip_note ||= WipDetails.new(spec, path_redaction: @settings.path_redaction, session: info)
    end

    def provenance_spec
      @content.fetch('provenance') { raise Error, 'Publication description requires execution provenance.' }
    end

    # The current head's intervals open the Timings section.
    def timings
      @timings ||= TimingsDetails.for(@timeline, @settings.time_zone).map do |item|
        details_block(item.merge('body' => "#{ThroughputStats.line(throughput)}\n\n#{item['body']}"))
      end
    end

    def missing_values
      detail = MissingValues.detail(throughput, @content, timings: timings.any?)
      detail ? [details_block(detail)] : []
    end

    def throughput = @throughput ||= ThroughputStats.state(@content, @timeline, @pull)

    # The table and the history both show the recommendation the history kept.
    def provenance
      spec = ProvenanceRecommendation.resolve(@pull, provenance_spec).spec
      execution = ExecutionProvenance.new(spec, workflow_version: @workflow_version, pull: @pull)
      detail = execution.detail
      return details_block(detail) unless @pull

      history = ProvenanceHistory.carry(@pull, execution.entry)
      body = [detail['body'], ProvenanceHistory.section(history), ProvenanceHistory.marker(history)].compact
      details_block(detail.merge('body' => body.join("\n\n")))
    end

    def skills_used = [details_block(SkillsUsed.new(@content['skills_used']).detail)]

    def task_history
      body = @content['task_history']
      body.nil? ? [] : [details_block('summary' => 'Task history', 'body' => body)]
    end
  end
end
