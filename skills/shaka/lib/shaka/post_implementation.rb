# frozen_string_literal: true

require 'optparse'
require_relative 'post_implementation_runner'
require_relative 'post_implementation/history'
require_relative 'github'
require_relative 'usage/codex_usage'
require_relative 'usage/claude_usage'

module Shaka
  # Runs and publishes one product checkpoint on the existing PR.
  class PostImplementation
    KEY = 'post-implementation'

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
      raise Error, 'Usage: shaka post-implementation (run|publish) [options]' unless %w[run publish].include?(action)

      flags = parser(action)
      flags.parse!(@arguments)
      return 0.tap { puts flags } if @options[:help]

      raise Error, '--content-file is required' if action == 'publish' && !@options[:content_file]

      present(action == 'run' ? execute : publish, action)
    end

    def present(result, action)
      puts JSON.pretty_generate(result)
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
      live = github.snapshot.values_at('state', 'headRefOid')
      raise Error, 'Checkpoint is not for the live open PR head' unless live == ['OPEN', head]

      published = github.reply(body: render(result, head), key: "#{KEY}-#{head[0, 7]}-#{result.fetch('execution_id')}")
      published.merge('earlier_checkpoints' => PostImplementationHistory.new(github).collapse(published))
    end

    def publication_result
      result = JSON.parse(File.read(@options.fetch(:content_file), encoding: 'UTF-8'))
      raise Error, 'Checkpoint result must be an object' unless result.is_a?(Hash)
      raise Error, 'Not a product checkpoint result' unless result['purpose'] == 'post_implementation'
      raise Error, 'Checkpoint has no execution identity' unless
        result['execution_id'].to_s.match?(/\A[0-9a-f]{8}\z/)

      result
    end

    def render(result, head)
      title = "#{identity_text(result)}\n\n## Post-implementation validation\n\nHead: `#{head}`\n\n"
      return title + "**Opted out:** #{result.fetch('reason')}\n" if result['status'] == 'opted_out'
      unless result['status'] == 'completed'
        return title + "**Not completed.** #{result.fetch('reason')}\n\nReadiness remains blocked.\n"
      end

      title + completed_body(result, head)
    end

    def identity_text(result)
      configuration = result['usage'] && native_usage(result, result['usage']).last&.fetch('configuration')
      provider, family = result.fetch('reviewer', 'UNKNOWN/UNKNOWN').split('/', 2)
      PublicationText.identity('agent' => family, 'provider' => provider,
                               'model' => configuration && (configuration[2] || configuration[1]),
                               'effort' => configuration && configuration[3])
    end

    def completed_body(result, head)
      report = PostImplementationReport.read(result.fetch('report'), head:)
      concerns = report.fetch('concerns')
      ["**#{report.fetch('conclusion')}**", *report.fetch('reasons'),
       "Simpler alternative: #{report.fetch('alternative')}",
       "Unresolved concerns: #{concerns.empty? ? 'none' : concerns.join('; ')}",
       settings_text(result), usage_text(result),
       'Ruby verified report shape and head binding. The reviewer judged value; the task owner handles concerns ' \
       'and merge readiness. This does not attest to technical review.'].join("\n\n")
    end

    def settings_text(result)
      "Reviewer: #{result.fetch('reviewer')}; requested model: #{result.fetch('requested_model', 'CLI default')}; " \
        "effort: #{result.fetch('effort')}; prompt: #{result.fetch('prompt_source')}."
    end

    def usage_text(result)
      usage = result['usage']
      return 'Observed model and usage: UNKNOWN (provider supplied no native record).' unless usage

      "<details><summary>Native execution usage</summary>\n\n```json\n" \
        "#{JSON.pretty_generate(native_usage(result, usage))}\n```\n\n</details>"
    end

    def native_usage(result, path)
      reader = result['reviewer'] == 'openai/codex' ? CodexUsage : ClaudeUsage
      source = reader.new([path], [], all_turns: true)
      source.responses.values.map { |entry| entry.slice('configuration', 'usage') }
    end

    def parser(action)
      OptionParser.new do |flags|
        flags.banner = "Usage: shaka post-implementation #{action} [options]"
        %w[root base head reviewer model effort prompt-file content-file timeout-seconds opt-out].each do |key|
          flags.on("--#{key} VALUE") { |value| @options[key.tr('-', '_').to_sym] = value }
        end
        flags.on('--ref SHA') { |value| @options[:criteria_ref] = value }
        flags.on('-h', '--help') { @options[:help] = true }
      end
    end
  end
end
