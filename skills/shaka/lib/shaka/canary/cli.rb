# frozen_string_literal: true

require 'json'
require 'time'
require_relative 'gate'
require_relative 'pulls'
require_relative 'body'
require_relative 'text'
require_relative 'report'
require_relative 'run'

module Shaka
  module Canary
    # Command line the canary workflow calls. Decisions stay in the modules above.
    module Cli
      USAGE = 'Usage: bin/canary preflight|throttle|prompt|report|collect|publish|finish|close-list [options]'

      module_function

      def run(argv)
        command = argv.shift
        handler = commands.fetch(command) { raise ArgumentError, USAGE }
        handler.call(argv)
      rescue ArgumentError, JSON::ParserError, KeyError => e
        warn "shaka canary: #{e.message}"
        1
      end

      def commands
        { 'preflight' => method(:preflight), 'throttle' => method(:throttle), 'prompt' => method(:prompt),
          'report' => method(:report), 'collect' => method(:collect), 'publish' => method(:publish),
          'finish' => method(:finish), 'close-list' => method(:close_list) }
      end

      def preflight(_argv)
        result = Preflight.decide(ENV)
        Preflight.write_output(result, ENV.fetch('GITHUB_OUTPUT')) if ENV['GITHUB_OUTPUT']
        puts JSON.generate(result)
        result['action'] == 'invalid' ? 1 : 0
      end

      def throttle(argv)
        options = Flags.parse(argv)
        runs = JSON.parse(File.read(options.fetch('runs')))
        last = Throttle.latest_finish(runs)
        puts Throttle.wait_seconds(last_finished_at: last, now: Time.now.utc,
                                   manual: options['event'] == 'workflow_dispatch')
        0
      end

      def prompt(argv)
        options = Flags.parse(argv)
        puts Prompt.render(sha: options.fetch('sha'), repo: options.fetch('repo'))
        0
      end

      def report(argv)
        options = Flags.parse(argv)
        result = Report.build(JSON.parse(File.read(options.fetch('input'))))
        File.write(options.fetch('summary'), result.fetch('summary'))
        File.write(options.fetch('result'), JSON.generate(result))
        append_summary(result.fetch('summary'))
        0
      end

      def collect(_argv)
        Collect.call(ENV)
        0
      end

      def publish(_argv)
        Publish.call(ENV)
      end

      def finish(argv)
        options = Flags.parse(argv)
        result = JSON.parse(File.read(options.fetch('result')))
        result['ok'] == true ? 0 : 1
      end

      def close_list(argv)
        options = Flags.parse(argv)
        result = JSON.parse(File.read(options.fetch('result')))
        Array(result['close']).each { |number| puts number }
        0
      end

      def append_summary(text)
        path = ENV.fetch('GITHUB_STEP_SUMMARY', nil)
        return unless path

        File.write(path, "#{text}\n", mode: 'a')
      end
    end
  end
end
