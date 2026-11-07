# frozen_string_literal: true

require_relative '../merge_review_floor'
require_relative '../repository_config/protected_areas_schema'
require_relative 'auto_merge_preview'

module Shaka
  # The checkpoint's risk rating, raised to high for any change inside a protected area, and what each
  # rating asks of the merge. A preview: nothing here changes what merges.
  module PostImplementationRisk
    GLOB = File::FNM_PATHNAME | File::FNM_EXTGLOB | File::FNM_DOTMATCH
    ACTION = {
      'low' => 'Low risk is meant for auto-merge, with a later audit.',
      'medium' => 'Medium risk is meant for a person to merge after a skim: the description, these reasons, ' \
                  'and the verification, then only the files the reasons name.',
      'high' => 'High risk is meant for a person to merge after a careful review that starts with the ' \
                'verification: does the evidence prove the change works, before the code?'
    }.freeze

    module_function

    # rating is the reviewer's; areas maps names to path patterns; paths are the PR's changed files, or nil
    # when they could not be read, which counts as high because a protected change cannot be ruled out.
    def assess(rating, areas, paths)
      hits = paths ? protected(areas, paths) : []
      level = !paths || hits.any? || rating == 'unknown' ? 'high' : rating
      { 'rating' => rating, 'level' => level, 'protected' => hits, 'paths_read' => !paths.nil? }
    end

    # The checkpoint's two Ruby-computed previews. seam reads the trusted settings when a completed
    # checkpoint renders; an incomplete one reads none.
    def previews(seam, github, pull, head)
      { auto_merge: ->(verdict) { AutoMergePreview.line(seam.call, github, pull, head, verdict) },
        risk: ->(rating) { from(seam.call, github, head, rating) } }
    end

    # seam is the trusted RepositoryConfig, or nil when it could not be read, which applies the packaged areas.
    # Changed files that GitHub cannot list count as unread.
    def from(seam, github, head, rating)
      areas = seam&.protected_areas || RepositoryConfig::ProtectedAreasSchema.effective(nil)
      paths = begin
        MergeReviewFloor.new.paths(github, head)
      rescue Error
        nil
      end
      assess(rating, areas, paths)
    end

    # The first changed file in each area, so a reader sees why the area applies.
    def protected(areas, paths)
      areas.filter_map do |name, globs|
        path = paths.find { |candidate| globs.any? { |glob| File.fnmatch?(glob, candidate, GLOB) } }
        { 'area' => name, 'path' => path } if path
      end
    end

    def section(assessment, reasons)
      lines = ["**Risk:** #{heading(assessment)} #{ACTION.fetch(assessment['level'])}"]
      lines.concat(reasons.map { |reason| "- #{reason}" })
      lines << '- Changed files could not be read, so protected areas were not checked.' unless
        assessment['paths_read']
      "#{lines.join("\n")}\n\n_Preview: the rating does not change what merges yet; merge settings still decide._"
    end

    # The PR's author names its files, so a backtick or line break must not end the code span and let the
    # rest of the name render as Markdown in a comment the maintainer's account publishes.
    def inert(path) = path.gsub(/[`\r\n]/, '?')

    def heading(assessment)
      level = assessment['level'].capitalize
      rated = assessment['rating']
      raised = assessment['protected'].map { |hit| "`#{hit['area']}` (`#{inert(hit['path'])}`)" }
      return "#{level}, raised from the reviewer's #{rated} by #{raised.join(', ')}." if raised.any? && rated != 'high'
      return "#{level}, inside #{raised.join(', ')}." if raised.any?
      return "#{level}; the reviewer could not judge it, so it counts as high." if rated == 'unknown'

      "#{level}."
    end
  end
end
