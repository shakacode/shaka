# frozen_string_literal: true

require_relative '../merge_review_floor'
require_relative '../configuration/feature_guard'
require_relative '../repository_config/high_risk_areas_schema'

module Shaka
  # The checkpoint's risk rating, raised to high for any change inside a high-risk area, and what each
  # rating asks of the merge. Merge reads the rating only under merge.auto_merge: low, through MergeRiskGate.
  module PostImplementationRisk
    # Case-insensitive, because a case-insensitive checkout changes Infra/main.tf as surely as infra/main.tf.
    GLOB = File::FNM_PATHNAME | File::FNM_EXTGLOB | File::FNM_DOTMATCH | File::FNM_CASEFOLD
    ACTION = {
      'low' => 'Low risk is meant for auto-merge, with a later audit.',
      'medium' => 'Medium risk is meant for a person to merge after a skim: the description, these reasons, ' \
                  'and the verification, then only the files the reasons name.',
      'high' => 'High risk is meant for a person to merge after a careful review that starts with the ' \
                'verification: does the evidence prove the change works, before the code?'
    }.freeze

    module_function

    # rating is the reviewer's; areas maps names to path patterns; paths are the PR's changed files, or nil
    # when they could not be read, which counts as high because a high-risk change cannot be ruled out.
    def assess(rating, areas, paths)
      hits = paths ? hits(areas, paths) : []
      level = !paths || hits.any? || rating == 'unknown' ? 'high' : rating
      { 'rating' => rating, 'level' => level, 'areas_hit' => hits, 'paths_read' => !paths.nil? }
    end

    # The checkpoint's two Ruby-computed previews; the caller loads AutoMergePreview, which requires this file.
    # seam reads the trusted settings when a completed checkpoint renders; an incomplete one reads none.
    def previews(seam, github, pull, head)
      { auto_merge: ->(checkpoint) { AutoMergePreview.line(seam.call, github, pull, head, checkpoint) },
        risk: ->(rating) { from(seam.call, github, head, rating) } }
    end

    # seam is the trusted RepositoryConfig, or nil when it could not be read, which applies the packaged areas.
    # Changed files that GitHub cannot list count as unread. governs says whether merge reads the rating.
    def from(seam, github, head, rating)
      areas = seam&.high_risk_areas || RepositoryConfig::HighRiskAreasSchema.effective(nil)
      paths = begin
        MergeReviewFloor.new.paths(github, head)
      rescue Error, SystemCallError
        nil
      end
      assess(rating, areas, paths).merge('governs' => seam&.merge&.fetch('auto_merge') == 'low')
    end

    # The first changed file in each area, so a reader sees why the area applies. Shaka's own configuration
    # counts as the shaka area even where a repository narrows or turns that area off, as merge always holds it.
    def hits(areas, paths)
      found = areas.filter_map do |name, globs|
        path = paths.find { |candidate| globs.any? { |glob| File.fnmatch?(glob, candidate, GLOB) } }
        { 'area' => name, 'path' => path } if path
      end
      found + configuration_hit(found, paths)
    end

    def configuration_hit(found, paths)
      return [] if found.any? { |hit| hit['area'] == 'shaka' }

      path = paths.find { |candidate| Configuration::FeatureGuard.configuration?(candidate) }
      path ? [{ 'area' => 'shaka', 'path' => path }] : []
    end

    def section(assessment, reasons)
      lines = ["**Risk:** #{heading(assessment)} #{ACTION.fetch(assessment['level'])}"]
      lines.concat(reasons.map { |reason| "- #{reason}" })
      lines << '- Changed files could not be read, so high-risk areas were not checked.' unless
        assessment['paths_read']
      "#{lines.join("\n")}\n\n#{footnote(assessment)}"
    end

    def footnote(assessment)
      return '_With `merge.auto_merge: low`, an agent merges only a low rating; a person merges the rest._' if
        assessment['governs']

      '_Preview: the rating does not change what merges until `merge.auto_merge` is `low`._'
    end

    # The PR's author names its files, so a backtick or line break must not end the code span and let the
    # rest of the name render as Markdown in a comment the maintainer's account publishes.
    def inert(path) = path.gsub(/[`\r\n]/, '?')

    def heading(assessment)
      level = assessment['level'].capitalize
      rated = assessment['rating']
      raised = assessment['areas_hit'].map { |hit| "`#{hit['area']}` (`#{inert(hit['path'])}`)" }
      return "#{level}, raised from the reviewer's #{rated} by #{raised.join(', ')}." if raised.any? && rated != 'high'
      return "#{level}, inside #{raised.join(', ')}." if raised.any?
      return "#{level}; the reviewer could not judge it, so it counts as high." if rated == 'unknown'

      "#{level}."
    end
  end
end
