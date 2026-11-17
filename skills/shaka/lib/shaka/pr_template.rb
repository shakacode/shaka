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
    COMMENT = /<!--.*?-->/
    FENCE = /\A {0,3}(`{3,}|~{3,})/
    CLOSER = /\A {0,3}(`{3,}|~{3,})[ \t]*\z/
    HEADING = /\A {0,3}##[ \t]+(.*?)(?:[ \t]+#+)?[ \t]*\z/

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
    def self.headings(text) = HeadingReader.new.call(text)

    # Reads a template line by line. Text inside a code block or an HTML comment is literal, so comment
    # syntax in a code block and a heading inside a comment both stay hidden.
    class HeadingReader
      def initialize
        @fence = nil
        @comment = false
      end

      def call(text) = text.each_line(chomp: true).filter_map { read(it) }

      private

      def read(line)
        if @fence
          @fence = nil if closes?(line)
        elsif @comment
          @comment = !line.include?('-->')
        elsif (marker = line[FENCE, 1])
          @fence = marker
        else
          return heading(line)
        end
        nil
      end

      # A comment the line opens hides the lines after it; one before the heading marks hides the heading.
      def heading(line)
        @comment = line.gsub(COMMENT, '').include?('<!--')
        text = line[HEADING, 1]
        text = text.gsub(COMMENT, '').sub(/<!--.*/, '').strip if text
        text unless text.to_s.empty?
      end

      # Only a bare run of the opening character, at least as long, closes a code block.
      def closes?(line)
        (closer = line[CLOSER, 1]) && closer[0] == @fence[0] && closer.size >= @fence.size
      end
    end
  end
end
