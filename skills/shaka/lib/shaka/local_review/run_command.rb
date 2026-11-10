# frozen_string_literal: true

require 'optparse'
require_relative '../call_log'

module Shaka
  # `shaka review run`. A caller waits on its JSON, so an argument it cannot parse, such as
  # `--effort medium` passed as one word, answers with a setup failure, not just a stderr line.
  module LocalReviewRunCommand
    def review_run
      parser = run_parser
      parser.parse!(@arguments)
      return 0.tap { puts parser } if @options[:help]
      raise OptionParser::InvalidArgument, "unexpected argument #{@arguments.first.inspect}" unless @arguments.empty?

      present(dispatch('run'))
    rescue OptionParser::ParseError => e
      present({ 'status' => 'not_completed', 'head' => @options[:head], 'reviewer' => @options[:reviewer],
                'attempted' => false, 'failure_stage' => 'setup_failure', 'skip_evidence' => 'not_eligible',
                'reason' => e.message })
    end

    private

    def run_parser
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka review run --root DIR --base SHA --head SHA --reviewer ID'
        %w[root base head reviewer effort model criteria-ref settings-ref repository description-file timeout-seconds
           ledger max-review-executions budget-reason].each do |key|
          flags.on("--#{key} VALUE") { |value| CallLog.tag(key => @options[key.tr('-', '_').to_sym] = value) }
        end
        flags.on('-h', '--help') { @options[:help] = true }
      end
    end
  end
end
