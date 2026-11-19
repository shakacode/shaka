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

    # What a reader of `guidance pr_evidence` needs to see: the order Shaka will publish, worked out by the same
    # layout the description uses, the template headings Shaka keeps in its own sections, and any repeats.
    def self.check(outline)
      return [] unless outline.include?(MARKER)

      require_relative 'publication/template_layout'
      own, kept = (groups(outline).map(&:first) - [MARKER]).partition { TemplateLayout.placeable(it) }
      notes(TemplateLayout.arrange([MARKER], own.map { [{ 'heading' => it }, it] }, outline), kept, repeats(outline))
    end

    def self.notes(order, kept, repeated)
      ["Shaka will publish: #{order.map { it == MARKER ? "Shaka's sections" : heading(it) }.join(', ')}.",
       *kept.map { "#{heading(it)} is a section Shaka writes, so it stays inside Shaka's sections." },
       *repeated.map { "The template repeats #{it == MARKER ? MARKER_LINE : heading(it)}; Shaka uses the first." }]
    end

    def self.groups(outline) = outline.group_by { it == MARKER ? it : TemplateLayout.key(it) }.values
    def self.repeats(outline) = groups(outline).select { it.size > 1 }.map(&:first)
    def self.heading(name) = "`## #{name}`"

    private_class_method :notes, :groups, :repeats, :heading

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
