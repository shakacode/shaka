# frozen_string_literal: true

module Shaka
  # Groups workflow facts separately from a pull request's own evidence.
  module PublicationMetrics
    private

    # Only helper-owned metadata belongs here; caller-supplied details remain with the change's evidence.
    def metrics
      usage_detail = UsageDetails.new(@content['usage']).detail
      blocks = [details_block(usage_detail), *TimingsDetails.for(@timeline).map { |item| details_block(item) },
                provenance, details_block(@settings.detail), *skills_used, *task_history]
      ['## Shaka metrics', UsageEstimate.markdown(usage_detail),
       details_block('summary' => 'Details', 'body' => blocks.join("\n\n"))]
    end

    def provenance_spec
      @content.fetch('provenance') { raise Error, 'Publication description requires execution provenance.' }
    end

    def provenance
      execution = ExecutionProvenance.new(provenance_spec, workflow_version: @workflow_version, pull: @pull)
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
