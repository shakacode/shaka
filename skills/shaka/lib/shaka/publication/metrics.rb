# frozen_string_literal: true

module Shaka
  # Groups workflow facts separately from a pull request's own evidence.
  module PublicationMetrics
    private

    # Only helper-owned metadata belongs here; caller-supplied details remain with the change's evidence.
    def metrics
      usage_detail = UsageDetails.new(@content['usage']).detail
      execution, *history = provenance
      blocks = [details_block(usage_detail), *TimingsDetails.for(@timeline).map { |item| details_block(item) },
                execution, details_block(@settings.detail), *skills_used, *history, *task_history]
      ['## Shaka metrics', UsageEstimate.markdown(usage_detail),
       details_block('summary' => 'Details', 'body' => blocks.join("\n\n"))]
    end

    def provenance
      spec = @content.fetch('provenance') do
        raise Error, 'Publication description requires execution provenance.'
      end
      execution = ExecutionProvenance.new(spec, workflow_version: @workflow_version, pull: @pull)
      return [details_block(execution.detail)] unless @pull

      history = ProvenanceHistory.carry(@pull, execution.entry)
      detail = execution.detail
      marked = detail.merge('body' => "#{detail['body']}\n\n#{ProvenanceHistory.marker(history)}")
      [details_block(marked), *ProvenanceHistory.detail(history)&.then { |item| details_block(item) }]
    end

    def skills_used = [details_block(SkillsUsed.new(@content['skills_used']).detail)]

    def task_history
      body = @content['task_history']
      body.nil? ? [] : [details_block('summary' => 'Task history', 'body' => body)]
    end
  end
end
