# frozen_string_literal: true

require_relative '../defaults'
require_relative '../pull_changed_files'
require_relative '../configuration/feature_guard'
require_relative '../repository_config/high_risk_areas_schema'

module Shaka
  # The checkpoint's risk rating, raised to high for any change inside a high-risk area and from low to medium
  # inside a medium-risk area, and what each
  # rating asks of the merge. Merge reads the rating against merge.auto_merge_max_risk, through MergeRiskGate.
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
    LEVELS = %w[low medium high].freeze
    UNREAD_FILES = 'Changed files could not be read, so high-risk areas were not checked.'

    module_function

    DEFAULT_MAX = Defaults.fetch('merge', 'auto_merge_max_risk')

    # The trusted merge.auto_merge_max_risk, or the packaged level when the settings or the key are missing.
    def max_risk(seam) = seam&.merge&.[]('auto_merge_max_risk') || DEFAULT_MAX

    def within?(level, max_risk) = LEVELS.index(level) <= LEVELS.index(max_risk)

    # Every level a setting lets the agent merge, so medium reads as low or medium.
    def allowed(max_risk) = LEVELS.take(LEVELS.index(max_risk) + 1).join(' or ')

    # rating is the reviewer's; areas and medium map names to path patterns; paths are the PR's changed files,
    # or nil when they could not be read, which counts as high because a high-risk change cannot be ruled out.
    def assess(rating, areas, paths, medium = {})
      hits = paths ? hits(areas, paths) : []
      level = !paths || hits.any? || rating == 'unknown' ? 'high' : rating
      raised = level == 'low' ? area_hits(medium, paths) : []
      { 'rating' => rating, 'level' => raised.any? ? 'medium' : level, 'areas_hit' => hits,
        'medium_areas_hit' => raised, 'paths_read' => !paths.nil? }
    end

    # The packaged areas apply when the trusted settings cannot be read.
    def areas(seam)
      [seam&.high_risk_areas || RepositoryConfig::HighRiskAreasSchema.effective(nil),
       seam&.medium_risk_areas || RepositoryConfig::MediumRiskAreasSchema.effective(nil)]
    end

    # The checkpoint's two Ruby-computed previews; the caller loads AutoMergePreview, which requires this file.
    # seam reads the trusted settings when a completed checkpoint renders; an incomplete one reads none.
    def previews(seam, github, pull, head)
      { auto_merge: ->(checkpoint) { AutoMergePreview.line(seam.call, pull, checkpoint) },
        risk: ->(rating) { from(seam.call, github, head, rating) } }
    end

    # seam is the trusted RepositoryConfig, or nil when it could not be read, which applies the packaged areas.
    # Changed files that GitHub cannot list count as unread. max_risk is the level merge reads.
    def from(seam, github, head, rating)
      high, medium = areas(seam)
      paths = begin
        PullChangedFiles.new.paths(github, head)
      rescue Error, SystemCallError
        nil
      end
      assess(rating, high, paths, medium).merge('max_risk' => max_risk(seam))
    end

    # The first changed file in each area, so a reader sees why the area applies. Shaka's own configuration
    # counts as the shaka area even where a repository narrows or turns that area off, as merge always holds it.
    def hits(areas, paths)
      found = area_hits(areas, paths)
      found + configuration_hit(found, paths)
    end

    def area_hits(areas, paths)
      areas.filter_map do |name, globs|
        path = paths.find { |candidate| globs.any? { |glob| File.fnmatch?(glob, candidate, GLOB) } }
        { 'area' => name, 'path' => path } if path
      end
    end

    def configuration_hit(found, paths)
      return [] if found.any? { |hit| hit['area'] == 'shaka' }

      path = paths.find { |candidate| Configuration::FeatureGuard.configuration?(candidate) }
      path ? [{ 'area' => 'shaka', 'path' => path }] : []
    end

    def section(assessment, reasons)
      lines = ["**Risk:** #{heading(assessment)} #{action(assessment)}"]
      lines.concat(reasons.map { |reason| "- #{reason}" })
      lines << "- #{UNREAD_FILES}" unless assessment['paths_read']
      "#{lines.join("\n")}\n\n#{footnote(assessment)}"
    end

    # Under a max level that admits this level, the setting, not the design default, says who merges.
    def action(assessment)
      level = assessment['level']
      max = assessment.fetch('max_risk', DEFAULT_MAX)
      return ACTION.fetch(level) unless level != 'low' && within?(level, max)

      "#{level.capitalize} risk is at or below `merge.auto_merge_max_risk: #{max}`, so an agent may merge it, " \
        'with a later audit.'
    end

    def footnote(assessment)
      max = assessment.fetch('max_risk', DEFAULT_MAX)
      "_With `merge.auto_merge_max_risk: #{max}`, an agent merges a #{allowed(max)} rating; a person merges the " \
        'rest._'
    end

    # The PR's author names its files, so a backtick or line break must not end the code span and let the
    # rest of the name render as Markdown in a comment the maintainer's account publishes.
    def inert(path) = path.gsub(/[`\r\n]/, '?')

    def heading(assessment)
      level = assessment['level'].capitalize
      rated = assessment['rating']
      raised = (assessment['areas_hit'] + assessment.fetch('medium_areas_hit', [])).map do |hit|
        "`#{hit['area']}` (`#{inert(hit['path'])}`)"
      end
      return "#{level}, raised from the reviewer's #{rated} by #{raised.join(', ')}." if raised.any? && rated != 'high'
      return "#{level}, inside #{raised.join(', ')}." if raised.any?
      return "#{level}; the reviewer could not judge it, so it counts as high." if rated == 'unknown'

      "#{level}."
    end
  end
end
