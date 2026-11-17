# frozen_string_literal: true

require_relative 'error'
require_relative 'trusted_config_source'
require_relative 'trusted_path_resolver'

module Shaka
  # Finds the repository's single pull request template at a trusted commit, in GitHub's locations.
  module PrTemplate
    PATHS = %w[.github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md
               pull_request_template.md PULL_REQUEST_TEMPLATE.md
               docs/pull_request_template.md docs/PULL_REQUEST_TEMPLATE.md].freeze
    # One left-to-right scan in reading order: whichever of a code block, code span, or comment opens
    # first hides the others' syntax inside it, as GitHub renders them. Only headings are kept.
    TOKENS = /
      ^[ ]{0,3}(?<ticks>`{3,})[^\n]*(?:\n.*?(?:^[ ]{0,3}\k<ticks>`*[ \t]*$|\z)|\z)
      | ^[ ]{0,3}(?<tildes>~{3,})[^\n]*(?:\n.*?(?:^[ ]{0,3}\k<tildes>~*[ \t]*$|\z)|\z)
      | `[^`\n]+`
      | <!--.*?(?:-->|\z)
      | ^[ ]{0,3}\#\#[ \t]+(?<heading>(?:(?!<!--)[^\n])*)
    /mx

    # A location that cannot be resolved, such as a symlink loop, counts as no template there. Once
    # repaired, the template becomes a new fingerprint input, so earlier evidence still goes stale.
    def self.path(root:, sha:)
      resolver = TrustedPathResolver.new(root:, sha:)
      PATHS.find do |path|
        resolver.resolve(path).last&.last == 'blob'
      rescue Error
        false
      end
    end

    # The headings that lay out a description: the template orders one only where the agent reads it,
    # beside the PR evidence guide.
    # An unreadable template keeps the usual order; `guidance pr_evidence` tells the agent why it was skipped.
    def self.layout(root:, ref:, config:)
      return unless (guide = config&.project_guidance&.fetch('pr_evidence', nil))

      require_relative 'configuration'
      require_relative 'opening_publication'
      OpeningPublication.with_safe_path(root:, select_gh: false) do |candidate_root|
        sha = config.sha || Configuration.resolve_commit(root: candidate_root, ref:, label: 'description ref')
        read(root: candidate_root, sha:, guide:)&.then { headings(it) }
      end
    rescue Error, SystemCallError
      nil
    end

    # The template the agent reads with the PR evidence guide: the guide itself when it names a template.
    def self.read(root:, sha:, guide:)
      path = PATHS.include?(guide) ? guide : path(root:, sha:)
      TrustedConfigSource.new(root:).read_prompt(path, sha, 'pull request template') if path
    end

    # The `##` headings a reader of the template sees, in order.
    def self.headings(text)
      text.gsub("\r\n", "\n").to_enum(:scan, TOKENS).filter_map do
        heading = Regexp.last_match[:heading]&.sub(/[ \t]+#+[ \t]*\z/, '')&.strip
        heading unless heading.to_s.empty?
      end
    end
  end
end
