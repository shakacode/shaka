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
    # The one line that marks where Shaka's sections go. GitHub hides it, and it is never a section to fill.
    MARKER_LINE = '<!-- shaka -->'
    MARKER = :shaka
    # Markdown lets a code fence, opening or closing, sit up to three spaces in.
    FENCE = /\A {0,3}(`{3,}(?=[^`]*\z)|~{3,})/

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

    # The template's outline, which orders a description only where the agent reads the template, beside the
    # PR evidence guide. An unreadable template keeps the usual order; `guidance pr_evidence` says why.
    def self.layout(root:, ref:, config:)
      return unless (guide = config&.project_guidance&.fetch('pr_evidence', nil))

      require_relative 'configuration'
      require_relative 'opening_publication'
      OpeningPublication.with_safe_path(root:, select_gh: false) do |candidate_root|
        sha = config.sha || Configuration.resolve_commit(root: candidate_root, ref:, label: 'description ref')
        read(root: candidate_root, sha:, guide:)&.then { outline(it) }
      end
    rescue Error, SystemCallError
      nil
    end

    # The template the agent reads with the PR evidence guide: the guide itself when it names a template.
    def self.read(root:, sha:, guide:)
      path = PATHS.include?(guide) ? guide : path(root:, sha:)
      TrustedConfigSource.new(root:).read_prompt(path, sha, 'pull request template') if path
    end

    # The template's section headings and marker, in order. The format is strict, so nothing is guessed: a
    # heading is a line starting `## ` at the left edge, the marker is exactly MARKER_LINE, and fenced code
    # blocks and HTML comments that start a line hold neither.
    def self.outline(text) = OutlineReader.new.call(text)

    # What a reader of `guidance pr_evidence` needs to know: that Shaka found the marker, the rule it applies,
    # and any repeats. It predicts no order, because the sections the agent writes decide that.
    def self.check(outline)
      return [] unless outline.include?(MARKER)

      ["Shaka places its sections at #{MARKER_LINE}. Sections the agent writes under the template's other `##` " \
       "headings follow the template's order; Shaka's own headings stay inside Shaka's sections.",
       *repeats(outline).map { "The template repeats #{name(it)}; Shaka uses the first." }]
    end

    def self.name(entry) = entry == MARKER ? MARKER_LINE : "`## #{entry}`"

    # Headings group as the description layout matches them, by words, ignoring case and spacing.
    def self.repeats(outline)
      outline.group_by { it == MARKER ? it : it.gsub(/[[:space:]]+/, ' ').downcase }.values
             .select { it.size > 1 }.map(&:first)
    end

    private_class_method :repeats, :name

    # Reads a template line by line, keeping code-block and comment state.
    class OutlineReader
      def initialize
        @fence = nil
        @comment = false
      end

      def call(text) = text.each_line(chomp: true).filter_map { read(it) }

      private

      def read(line)
        return if hidden?(line)
        return MARKER if line == MARKER_LINE

        heading = line.delete_prefix('## ').strip if line.start_with?('## ')
        heading unless heading.to_s.empty?
      end

      # Advances the code-block and comment state; true when the line belongs to either or opens one.
      def hidden?(line)
        if @fence then @fence = nil if line.rstrip.match?(/\A {0,3}#{Regexp.escape(@fence[0])}{#{@fence.size},}\z/)
        elsif @comment then @comment = !line.include?('-->')
        else return opens?(line)
        end
        true
      end

      # Whether the line opens a code block or comment; the marker line opens neither.
      def opens?(line)
        return false if line == MARKER_LINE

        if (opener = line[FENCE, 1]) then @fence = opener
        elsif line.start_with?('<!--') then @comment = !line.index('-->', 2)
        else return false
        end
        true
      end
    end
  end
end
