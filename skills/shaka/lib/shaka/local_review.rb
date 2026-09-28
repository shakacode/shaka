# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'error'
require_relative 'github'
require_relative 'local_review/comment'
require_relative 'local_review/runner'
require_relative 'local_review/report_check'

module Shaka
  # Entry point for process-verified reviews and explicitly weaker host reports.
  class LocalReview
    def self.run(arguments, github: nil)
      new(arguments, github:).run
    rescue OptionParser::ParseError, SystemCallError, JSON::ParserError, Shaka::Error => e
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
      unless %w[run check publish].include?(action)
        raise OptionParser::InvalidArgument, 'Usage: shaka review (run|check|publish) [options]'
      end

      parser = { 'run' => run_parser, 'check' => check_parser, 'publish' => publish_parser }.fetch(action)
      parser.parse!(@arguments)
      return show_help(parser) if @options[:help]
      return publish(parser) if action == 'publish'

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
        %w[root base head reviewer effort model criteria-ref description-file timeout-seconds].each do |key|
          flags.on("--#{key} VALUE") { |value| @options[key.tr('-', '_').to_sym] = value }
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

    # The comment is review evidence for the head it attests, so it may only describe the pushed head.
    def publish(parser)
      raise OptionParser::InvalidArgument, parser.to_s unless @arguments.length == 2 && @options[:content_file]

      comment = LocalReviewComment.new(JSON.parse(File.read(@options[:content_file], encoding: 'UTF-8')))
      github = @github || GitHub.new(*@arguments)
      require_pushed_head!(github, comment.head)
      puts JSON.pretty_generate(github.reply(body: comment.render, key: LocalReviewComment::KEY))
      0
    end

    def require_pushed_head!(github, head)
      pushed = github.snapshot.fetch('headRefOid')
      raise Shaka::Error, "The last review round covers #{head}, but the PR head is #{pushed}." unless pushed == head
    end

    def publish_parser
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka review publish OWNER/REPO NUMBER --content-file PATH'
        flags.on('--content-file PATH') { |value| @options[:content_file] = value }
        flags.on('-h', '--help') { @options[:help] = true }
      end
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
