# frozen_string_literal: true

require_relative 'usage'
require_relative 'journal'

module Shaka
  # Publishes selected native usage or collects the PR's durable response records.
  module UsageJournalCommand
    module_function

    def dispatch(arguments)
      valid_action?(arguments.first) ? run(arguments) : Usage.run(arguments)
    end

    def run(arguments)
      return help if arguments.intersect?(%w[-h --help])

      action, repository, number = arguments.shift(3)
      raise Error, 'Usage: shaka usage publish|collect OWNER/REPO NUMBER [options]' unless valid_action?(action)

      puts JSON.pretty_generate(execute(action, repository, number, parse(arguments)))
      0
    rescue OptionParser::ParseError, Error => e
      warn UsageErrors.message(e)
      1
    end

    def execute(action, repository, number, options)
      journal = UsageJournal.new(GitHub.new(repository, number))
      action == 'collect' ? journal.collect : journal.publish(records(options), event: options[:event])
    end

    def valid_action?(action) = %w[publish collect].include?(action)

    def parse(arguments)
      options = { files: [], turns: [], host: Usage.detected_host, format: 'json', event: 'checkpoint' }
      parser(options).parse!(arguments)
      raise OptionParser::InvalidArgument unless arguments.empty?

      options
    end

    def help
      puts parser({})
      0
    end

    def parser(options)
      parser = Usage.parser(options)
      parser.banner = 'Usage: shaka usage publish|collect OWNER/REPO NUMBER [options]'
      parser.on('--event NAME', UsageJournal::EVENTS) { |value| options[:event] = value }
      parser
    end

    def records(options)
      raise OptionParser::InvalidArgument unless Usage.valid_mapping?(options)

      Usage.new(options).response_records
    end
  end
end
