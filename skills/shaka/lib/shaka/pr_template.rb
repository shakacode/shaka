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
    # A backtick fence's opening line holds no other backtick, so ```npm test``` is inline code, not a fence.
    FENCE = /\A {0,3}(`{3,}(?=[^`]*\z)|~{3,})/
    CLOSER = /\A {0,3}(`{3,}|~{3,})[ \t]*\z/
    COMMENT_START = /\A {0,3}<!--/
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

    # Reads block by block, as GitHub does: a code block, or an HTML comment that starts a line, hides
    # every line until it closes. Other text cannot hide a later heading, because a heading line always
    # starts a new block.
    class HeadingReader
      def initialize
        @fence = nil
        @comment = false
      end

      def call(text) = text.each_line(chomp: true).filter_map { read(it) }

      private

      def read(line) = hidden?(line) ? nil : heading(line)

      # Advances the code-block and comment state; true when the line belongs to either.
      def hidden?(line)
        if @fence then @fence = nil if closes?(line)
        elsif @comment then @comment = open_after?(line, true)
        elsif (marker = line[FENCE, 1]) then @fence = marker
        elsif line.match?(COMMENT_START) then @comment = open_after?(line, false)
        else return false
        end
        true
      end

      # A heading counts by its exact words; a note belongs on its own line below it.
      def heading(line)
        text = line[HEADING, 1].to_s.strip
        text unless text.empty?
      end

      # Whether a comment is still open after the line, reading each opener and closer in order. A closer
      # may share the opener's dashes, as GitHub reads `<!-->` as a whole, empty comment.
      def open_after?(line, open)
        position = 0
        while (found = line.index(open ? '-->' : '<!--', position))
          position = found + (open ? 3 : 2)
          open = !open
        end
        open
      end

      # Only a bare run of the opening character, at least as long, closes a code block.
      def closes?(line)
        (closer = line[CLOSER, 1]) && closer[0] == @fence[0] && closer.size >= @fence.size
      end
    end
  end
end
