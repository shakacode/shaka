# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'tmpdir'
require_relative 'configuration'
require_relative 'error'
require_relative 'local_review/path_guard'
require_relative 'prompt_show/views'

module Shaka
  # `shaka prompt show NAME`: the prompt a reviewer receives, each part labeled with its source.
  module PromptShow
    OPERATIONS = %w[show].freeze
    VIEWS = { 'review' => 'ReviewView', 'checkpoint' => 'CheckpointView', 'opening' => 'OpeningView' }.freeze
    SHA = /\A\h{40}\z/
    USAGE = 'Usage: shaka prompt show (review|checkpoint|opening) --root DIR (--ref SHA | --local) ' \
            '[--head REV --base REV] [--reviewer PROVIDER/FAMILY] [--format text|json]'

    def self.run(arguments)
      Command.new(arguments).run
    rescue OptionParser::ParseError, Error, SystemCallError => e
      warn "shaka: #{e.message}"
      1
    end

    # Parses the request, chooses the settings commit, and prints the view.
    class Command
      def initialize(arguments)
        @arguments = arguments.dup
        @options = { format: 'text', timeout_seconds: 120 }
      end

      def run
        parser.parse!(@arguments)
        return 0.tap { puts parser } if @options[:help]

        name = name!
        settings_commit!
        result = with_original_path { view(name).then { |view| [view.sections, view.notes] } }
        puts render(name, *result)
        0
      end

      private

      def name!
        operation, name = @arguments
        raise OptionParser::InvalidArgument, USAGE unless OPERATIONS.include?(operation) && VIEWS.key?(name) &&
                                                          @arguments.length == 2

        name
      end

      def settings_commit!
        validate_sources!
        @options[:root] = checkout_root
        @options[:criteria_ref] = DraftCommit.create(@options[:root]) if @options[:draft]
        # A selected settings preview replaces the settings, as it does for the reviewers; criteria stay at --ref.
        @preview = Configuration::SettingsPreview.ref(root: @options[:root]) unless @options[:draft]
      end

      def settings_ref = @preview || @options[:criteria_ref]

      def validate_sources!
        raise OptionParser::InvalidArgument, 'Pass exactly one of --ref SHA and --local' unless
          @options.key?(:criteria_ref) ^ @options.key?(:draft)
        raise OptionParser::InvalidArgument, 'Pass --head and --base together' unless
          @options.key?(:head) == @options.key?(:base)
        raise Error, '--ref must be a full commit SHA' unless @options.fetch(:criteria_ref, '0' * 40).match?(SHA)
      end

      def checkout_root
        directory = File.realpath(@options.fetch(:root, Dir.pwd))
        directory = File.dirname(directory) until checkout?(directory) || directory == File.dirname(directory)
        raise Error, '--root is not inside a Git checkout' unless checkout?(directory)

        directory
      end

      def checkout?(directory) = File.exist?(File.join(directory, '.git'))

      def view(name) = PromptShow.const_get(VIEWS.fetch(name)).new(@options)

      # The runners narrow PATH for the reviewer; this command leaves the caller's PATH as it found it.
      def with_original_path
        original = ENV.fetch('PATH', nil)
        yield
      ensure
        ENV['PATH'] = original
      end

      def render(name, sections, notes)
        sections = draft_labels(sections)
        return JSON.pretty_generate(document(name, sections, notes)) if @options[:format] == 'json'

        [*heading(name, sections), *notes.map { |note| "Note: #{note}" }, '',
         *sections.to_a.map { |section| "=== #{section.source} ===\n#{section.text.strip}\n" }].join("\n")
      end

      def document(name, sections, notes)
        { 'prompt' => name, 'settings_ref' => settings_ref, 'criteria_ref' => @options[:criteria_ref],
          'settings_preview' => !@preview.nil?, 'draft' => @options.key?(:draft), 'enabled' => !sections.nil?,
          'notes' => notes,
          'sections' => sections.to_a.map { |section| { 'source' => section.source, 'text' => section.text } } }
      end

      def heading(name, sections)
        lines = ["The #{name} prompt from #{settings_source}, in the order the reviewer reads it."]
        lines << 'A draft grants nothing; settings take effect only when their PR merges.' if @options[:draft]
        lines << "This prompt is not sent: the #{name} check is disabled in these settings." unless sections
        lines
      end

      def settings_source
        ref = @options[:criteria_ref]
        return "an untrusted draft commit #{ref} built from the working tree" if @options[:draft]
        return "the selected settings preview #{@preview}, with AGENTS.md criteria from #{ref}" if @preview

        "settings commit #{ref}"
      end

      def draft_labels(sections)
        return sections unless @options[:draft] && sections

        sections.map { |section| section.with(source: "untrusted draft: #{section.source}") }
      end

      def parser
        @parser ||= OptionParser.new do |flags|
          flags.banner = USAGE
          { root: '--root DIR', criteria_ref: '--ref SHA', head: '--head REV', base: '--base REV',
            reviewer: '--reviewer ID' }.each { |key, flag| flags.on(flag) { |value| @options[key] = value } }
          flags.on('--local', 'Read the working tree as an untrusted draft') { @options[:draft] = true }
          flags.on('--format FORMAT', %w[text json]) { |value| @options[:format] = value }
          flags.on('-h', '--help') { @options[:help] = true }
        end
      end
    end

    # A commit object holding the working tree's tracked files and nonignored new files, so a draft is read through
    # the same commit-based path as trusted settings. It writes only unreferenced objects, which `git gc` removes.
    module DraftCommit
      IDENTITY = { 'GIT_AUTHOR_NAME' => 'shaka', 'GIT_AUTHOR_EMAIL' => 'shaka@localhost',
                   'GIT_COMMITTER_NAME' => 'shaka', 'GIT_COMMITTER_EMAIL' => 'shaka@localhost' }.freeze

      def self.create(root)
        raise Error, 'A settings preview is active; run without --local to see the previewed settings' if
          Configuration::SettingsPreview.ref(root:)

        Dir.mktmpdir('shaka-prompt-draft-') do |directory|
          environment = IDENTITY.merge('GIT_INDEX_FILE' => File.join(directory, 'index'))
          # A copy of the real index keeps every tracked and staged path, even one an ignore rule matches. Its own
          # timestamp keeps Git's check for files edited in the same second as the index was written.
          index = File.expand_path(git({}, root, 'rev-parse', '--git-path', 'index'), root)
          FileUtils.cp(index, environment.fetch('GIT_INDEX_FILE'), preserve: true) if File.file?(index)
          git(environment, root, 'add', '--all', '--', '.')
          tree = git(environment, root, 'write-tree')
          git(environment, root, 'commit-tree', tree, '-m', 'shaka prompt show --local draft')
        end
      end

      # The same Git a review would use: never one the checkout itself supplies.
      def self.git(environment, root, *arguments)
        path = LocalReviewPathGuard.safe_path(ENV.fetch('PATH', ''), candidate_root: root, drop_candidate: true)
        executable = LocalReviewPathGuard.safe_executable(path, 'git', root) || raise(Error, 'git is not on PATH')
        output, error, status = Open3.capture3(environment, executable, '-C', root, *arguments)
        raise Error, "git #{arguments.first} failed: #{error.lines.first.to_s.strip}" unless status.success?

        output.strip
      end
    end
  end
end
