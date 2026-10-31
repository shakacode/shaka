# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'claim/names'
require_relative 'configuration'
require_relative 'defaults'
require_relative 'error'
require_relative 'git_origin'
require_relative 'merge_hold'
require_relative 'repo_prefix'
require_relative 'review_coverage'
require_relative 'publication/time_zone'

module Shaka
  # `shaka configure settings`: each repository setting with the value Shaka applies, its packaged
  # default, and whether the repository sets it. Effective values come from the resolvers that apply
  # each setting, and defaults from defaults.yml, so the report restates neither.
  module ConfigureSettings
    OPERATIONS = %w[settings].freeze
    REFERENCE = 'https://github.com/shakacode/shaka/blob/main/docs/settings.md'
    USAGE = 'Usage: shaka configure settings --root DIR (--ref SHA | --local)'
    SHA = /\A\h{40}\z/

    # What a resolver reads: the loaded settings, config.yml as written, and the checkout.
    Context = Data.define(:config, :raw, :root)

    # One documented setting: its key and how Shaka resolves it.
    Setting = Data.define(:key, :resolve) do
      def anchor = key.delete('.')
      def path = key.split('.')
    end

    def self.setting(key, &resolve) = Setting.new(key:, resolve:)

    def self.review(key) = setting("review.#{key}") { |context| context.config.review[key] }
    def self.merge(key) = setting("merge.#{key}") { |context| context.config.merge[key] }
    def self.description(key) = setting("pr_description.#{key}") { |context| context.config.pr_description[key] }

    # In the order docs/settings.md explains them.
    SETTINGS = [
      merge('preference'), merge('required_checks'), merge('limits'), merge('auto_max_review_floor'),
      setting('merge.hold_labels') { |context| MergeHold.from(context.config).labels },
      review('startup_check'), review('required'), review('ci_review_jobs'), review('ci_review_wait'),
      review('local_max_rounds'), review('local_review_agents'),
      *%w[local_review_count provider_coverage].map do |key|
        setting("review.#{key}") { |context| ReviewCoverage.setting(context.config.review, key) }
      end,
      setting('review.custom_instructions_file') do |context|
        RepositoryConfig::PromptFiles.review_custom_instructions(context.config.review).first
      end,
      review('replacement_prompt_file'),
      setting('checkpoint') do |context|
        RepositoryConfig::PostImplementationSchema.effective(context.config.review.fetch('post_implementation', {}))
      end,
      setting('project_guidance') { |context| context.config.project_guidance },
      setting('pr_description.opening_check') { |context| context.config.opening_check },
      setting('prose_limits') { |context| context.config.prose_limits },
      setting('base_branch') { |context| context.config.base_branch },
      setting('branches.name') do |context|
        Claim::Names.new(query: nil, template: context.config.to_h.dig('branches', 'name')).reported
      end,
      *%w[show_shaka_credit show_human_comments max_human_comments].map { |key| description(key) },
      setting('pr_description.time_zone') { |context| TimeZone.renderable(context.config.time_zone) },
      description('human_review_floors'),
      setting('wip.include_checkout_path') do |context|
        context.config.wip['include_checkout_path']
      end,
      setting('repo_prefix') do |context|
        RepoPrefix.display(configured: context.raw['repo_prefix'],
                           repository_name: GitOrigin.repository_name(root: context.root))['prefix']
      end,
      setting('version') { |context| context.raw['version'] }
    ].freeze

    def self.run(arguments)
      Command.new(arguments).run
    rescue OptionParser::ParseError, Error, SystemCallError => e
      warn "shaka: #{e.message}"
      1
    end

    # The packaged default at a setting's path, or nil when defaults.yml has none.
    def self.packaged_default(setting)
      setting.path.reduce(Defaults.data) { |node, key| node.is_a?(Hash) ? node[key] : nil }
    end

    # One report row. A compound setting matches when each part the repository sets equals its default.
    def self.row(setting, context)
      set = explicit?(context.raw, setting.path)
      value = context.raw.dig(*setting.path) if set
      default = packaged_default(setting)
      { 'key' => setting.key, 'set' => set, 'value' => value, 'effective' => setting.resolve.call(context),
        'default' => default, 'matches_default' => matches_default(set, value, default),
        'reference' => "#{REFERENCE}##{setting.anchor}" }
    end

    def self.matches_default(set, value, default)
      return if !set || default.nil?
      return value == default unless value.is_a?(Hash) && default.is_a?(Hash)

      value.all? { |key, part| default.key?(key) && default[key] == part }
    end

    def self.explicit?(raw, path)
      parent = path.size == 1 ? raw : raw.dig(*path[0..-2])
      parent.is_a?(Hash) && parent.key?(path.last)
    end

    # Parses the request, reads one settings source, and prints the report.
    class Command
      def initialize(arguments)
        @arguments = arguments.dup
        @options = {}
      end

      def run
        parser.parse!(@arguments)
        return 0.tap { puts parser } if @options[:help]
        raise OptionParser::InvalidArgument, USAGE unless @arguments == OPERATIONS

        root = checkout_root
        config, source, settings_ref = load(root)
        context = Context.new(config:, raw: config.explicit_settings, root:)
        puts JSON.pretty_generate(report(context, source, settings_ref))
        0
      end

      private

      def report(context, source, settings_ref)
        { 'source' => source, 'requested_ref' => @options[:ref], 'settings_ref' => settings_ref,
          'draft' => @options.key?(:local), 'config_path' => context.config.config_path,
          'settings' => SETTINGS.map { |setting| ConfigureSettings.row(setting, context) } }
      end

      # A selected settings preview replaces the settings, as it does for every other command.
      def load(root)
        raise OptionParser::InvalidArgument, 'Pass exactly one of --ref SHA and --local' unless
          @options.key?(:ref) ^ @options.key?(:local)
        return local(root) if @options[:local]
        raise Error, '--ref must be a full commit SHA' unless @options[:ref].match?(SHA)

        config, refs, kind = Configuration.resolve_source(root:, ref: @options[:ref], candidate_commands: false)
        [config, kind, refs[:preview_ref] || refs[:trusted_ref]]
      end

      def local(root)
        raise Error, 'A settings preview is active; run without --local to see the previewed settings' if
          Configuration::SettingsPreview.ref(root:)

        [Configuration.worktree(root:), 'untrusted draft', nil]
      end

      def checkout_root
        directory = File.realpath(@options.fetch(:root, Dir.pwd))
        directory = File.dirname(directory) until checkout?(directory) || directory == File.dirname(directory)
        raise Error, '--root is not inside a Git checkout' unless checkout?(directory)

        directory
      end

      def checkout?(directory) = File.exist?(File.join(directory, '.git'))

      def parser
        @parser ||= OptionParser.new do |flags|
          flags.banner = USAGE
          flags.on('--root DIR') { |value| @options[:root] = value }
          flags.on('--ref SHA', 'Settings at this default-branch commit') { |value| @options[:ref] = value }
          flags.on('--local', 'Settings in the working tree, as an untrusted draft') { @options[:local] = true }
          flags.on('-h', '--help') { @options[:help] = true }
        end
      end
    end
  end
end
