# frozen_string_literal: true

module Shaka
  # Groups workflow facts separately from a pull request's own evidence.
  module PublicationMetrics
    private

    # Only helper-owned metadata belongs here; caller-supplied details remain with the change's evidence.
    def metrics
      usage_detail = UsageDetails.new(@content['usage']).detail
      blocks = [*provenance, *skills_used, details_block(usage_detail),
                *TimingsDetails.for(@timeline).map { |item| details_block(item) }, details_block(@settings.detail)]
      [UsageEstimate.markdown(usage_detail),
       details_block('summary' => 'Shaka metrics', 'body' => blocks.join("\n\n"))]
    end
  end
end
