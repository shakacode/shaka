# frozen_string_literal: true

require_relative 'usage_archive'
require_relative '../prose_limits'

module Shaka
  # Publishes a guarded description after its usage archive plan fits.
  module DescriptionPublishing
    # A block builds the body from the pull request it replaces, using this same read.
    def description(body: nil, prose: ProseLimits.new)
      current = pull
      existing = current['body'].to_s
      archive = UsageArchive.new(self)
      readable = archive_pull(current, archive)
      rendered = publishable(block_given? ? yield(readable) : body)
      plan = archive.prepare(merge(existing, rendered))
      merged = publish_archive(plan, current, prose)
      confirmed(api(pull_path, method: 'PATCH', fields: { body: merged }), merged)
    end

    private

    def publish_archive(plan, current, prose)
      prose.verify_publication!(self, Publishing.managed_region(plan.preview), kind: :description, pull: current)
      verify_rendering(plan.preview)
      check_unchanged(current['body'].to_s, current)
      merged = check_length(plan.publish)
      return merged if merged == plan.preview

      verify_rendering(merged)
      check_unchanged(current['body'].to_s, current)
      merged
    end

    def archive_pull(current, archive)
      head = current.dig('head', 'repo', 'full_name')
      return current unless head && head == current.dig('base', 'repo', 'full_name')

      current.merge('body' => archive.expand(current['body'].to_s))
    end
  end
end
