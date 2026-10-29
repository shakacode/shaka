# frozen_string_literal: true

require 'optparse'
require_relative 'post_implementation_runner'
require_relative 'post_implementation/history'
require_relative 'post_implementation/publication'
require_relative 'post_implementation/disposition'
require_relative 'post_implementation/merge_warning'
require_relative 'post_implementation/auto_merge_preview'
require_relative 'trusted_config_source'
require_relative 'github'
require_relative 'handoff/walkthrough'
require_relative 'merge_queue_commit'
require_relative 'publication/squash_message'

module Shaka
  # Runs and publishes one product checkpoint on the existing PR.
  class PostImplementation
    KEY = 'post-implementation'
    ACTIONS = %w[run publish].freeze

    def self.run(arguments, github: nil)
      new(arguments, github:).run
    rescue OptionParser::ParseError, SystemCallError, JSON::ParserError, KeyError, TypeError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def initialize(arguments, github: nil)
      @arguments = arguments.dup
      @options = {}
      @github = github
    end

    def run
      action = @arguments.shift
      raise Error, "Usage: shaka post-implementation (#{ACTIONS.join('|')}) [options]" unless ACTIONS.include?(action)

      flags = parser(action)
      flags.parse!(@arguments)
      return 0.tap { puts flags } if @options[:help]

      raise Error, '--content-file is required' if action == 'publish' && !@options[:content_file]

      present(action == 'run' ? execute : publish, action)
    end

    def present(result, action)
      puts JSON.pretty_generate(result)
      return 1 if result.dig('merge_safeguard', 'state') == 'failed'
      return 1 if result.dig('earlier_checkpoints', 'unavailable')&.any?

      %w[completed opted_out].include?(result['status']) || action == 'publish' ? 0 : 1
    end

    private

    def execute
      raise Error, 'run takes no positional arguments' unless @arguments.empty?

      %i[root base head criteria_ref].each { |key| raise Error, "Missing #{key}" unless @options[key] }
      PostImplementationRunner.new(@options).run
    end

    def publish
      raise Error, 'publish needs OWNER/REPO NUMBER' unless @arguments.size == 2

      result = publication_result
      github = @github || GitHub.new(*@arguments)
      head = result.fetch('head')
      pull = github.snapshot
      live = pull.values_at('state', 'headRefOid')
      raise Error, 'Checkpoint is not for the live open PR head' unless live == ['OPEN', head]

      published = publish_body(github, result, head, pull)
      published.merge('earlier_checkpoints' => PostImplementationHistory.new(github).collapse(published))
               .merge(@queue && @options[:squash_message] ? { 'squash_message' => 'not_applied_merge_queue' } : {})
    end

    def publish_body(github, result, head, pull)
      renderer = result.key?('disposition') ? PostImplementationDispositionPublication : PostImplementationPublication
      message = -> { ready_message(github, head, pull) }
      auto_merge = ->(verdict) { AutoMergePreview.line(trusted_seam, github, pull, head, verdict) }
      publication = renderer.new(result, head:, repository: @arguments.first, message:, auto_merge:)
      published = github.reply(body: publication.render, key: "#{KEY}-#{head[0, 7]}-#{result.fetch('execution_id')}")
      safeguard = merge_safeguard(github, head, publication, published)
      published.merge('merge_safeguard' => safeguard)
    end

    # Settings come from the trusted default branch, never the PR; without --ref there is no preview.
    # The preview is advisory, so unreadable settings leave it out instead of blocking the checkpoint.
    def trusted_seam
      return unless @options[:criteria_ref]

      TrustedConfigSource.from_ref(root: @options[:root] || Dir.pwd, ref: @options[:criteria_ref])
    rescue Error, SystemCallError
      nil
    end

    def merge_safeguard(github, head, publication, published)
      PostImplementationMergeWarning.new(github).call(head:, publication:, published:)
    rescue Error, KeyError, TypeError => e
      { 'state' => 'failed', 'reason' => e.message, 'head' => head }
    end

    # A ready checkpoint closes the PR's reports, so the walkthrough it follows has to be there already.
    # A merge queue takes no message, so its checkpoint says what the queue writes instead.
    def ready_message(github, head, pull)
      unless Handoff::Walkthrough.new(github).revision == head
        raise Error, "Ready checkpoint follows this account's walkthrough for #{head}; publish the walkthrough first."
      end

      @queue = MergeQueueCommit.for(github, pull)
      @queue || squash_message(github)
    end

    def squash_message(github)
      path = @options[:squash_message]
      unless path
        raise Error,
              'Ready checkpoint requires --squash-message with the commit title and body.'
      end

      SquashMessage.for(github, JSON.parse(File.read(path, encoding: 'UTF-8')))
    end

    def publication_result
      result = JSON.parse(File.read(@options.fetch(:content_file), encoding: 'UTF-8'))
      raise Error, 'Checkpoint result must be an object' unless result.is_a?(Hash)
      raise Error, 'Not a product checkpoint result' unless result['purpose'] == 'post_implementation'
      raise Error, 'Checkpoint has no execution identity' unless
        result['execution_id'].to_s.match?(/\A[0-9a-f]{8}\z/)

      result
    end

    def parser(action)
      OptionParser.new do |flags|
        flags.banner = "Usage: shaka post-implementation #{action} [options]"
        %w[root base head reviewer model effort replacement-prompt-file content-file squash-message timeout-seconds
           opt-out].each do |key|
          flags.on("--#{key} VALUE") { |value| @options[key.tr('-', '_').to_sym] = value }
        end
        flags.on('--ref SHA') { |value| @options[:criteria_ref] = value }
        flags.on('-h', '--help') { @options[:help] = true }
      end
    end
  end
end
