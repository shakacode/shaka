# frozen_string_literal: true

module Shaka
  # Groups workflow facts separately from a pull request's own evidence.
  module PublicationMetrics
    private

    # Only helper-owned metadata belongs here; caller-supplied details remain with the change's evidence.
    def metrics
      usage_detail = UsageDetails.new(@content['usage']).detail
      blocks = [*missing_values, details_block(usage_detail), *timings,
                provenance, details_block(@settings.detail), *skills_used, *task_history]
      ['## Shaka metrics', "#{UsageEstimate.markdown(usage_detail)}#{ThroughputStats.took(throughput)}",
       details_block('summary' => 'Details', 'body' => blocks.join("\n\n"))]
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
