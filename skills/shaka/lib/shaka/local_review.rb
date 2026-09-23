# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'error'
require_relative 'local_review/runner'
require_relative 'local_review/report_check'

module Shaka
  # Entry point for process-verified reviews and explicitly weaker host reports.
  class LocalReview
    SHA = /\A[0-9a-f]{40}\z/

    def self.run(arguments)
      new(arguments).run
    rescue OptionParser::ParseError, SystemCallError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def initialize(arguments)
      @arguments = arguments.dup
      @options = {}
    end

    def run
      action = @arguments.shift
      unless %w[run check].include?(action)
        raise OptionParser::InvalidArgument, 'Usage: shaka review (run|check) [options]'
      end

      parser = action == 'run' ? run_parser : check_parser
      parser.parse!(@arguments)
      return show_help(parser) if @options[:help]

      raise OptionParser::InvalidArgument, parser.to_s unless @arguments.empty?

      present(dispatch(action))
    end

    private

    def present(result)
      puts JSON.pretty_generate(result)
      %w[completed reported].include?(result.fetch('status')) ? 0 : 1
    end

    def run_parser
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka review run --root DIR --base SHA --head SHA --reviewer ID'
        %w[root base head reviewer effort model].each do |key|
          flags.on("--#{key} VALUE") { |value| @options[key.to_sym] = value }
        end
        flags.on('-h', '--help') { @options[:help] = true }
      end
    end

    def dispatch(action)
      action == 'run' ? LocalReviewRunner.new(@options).run : LocalReviewReportCheck.new(@options).run
    end

    def show_help(parser)
      puts parser
      0
    end

    def check_parser
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka review check --head SHA (--reviewer ID --report PATH | --not-run-reason TEXT)'
        flags.on('--head SHA') { |value| @options[:head] = value }
        flags.on('--reviewer ID') { |value| @options[:reviewer] = value }
        flags.on('--report PATH') { |value| @options[:report] = value }
        flags.on('--not-run-reason TEXT') { |value| @options[:not_run_reason] = value }
        flags.on('-h', '--help') { @options[:help] = true }
      end
    end
  end
end
