# frozen_string_literal: true

require 'optparse'
require_relative '../publication/comment_history'
require_relative '../merge_review_evidence'
require_relative 'bot_history'

module Shaka
  # Earlier reports retain their findings and their closing merge attestation.
  # A different reviewed commit is history, not proof that any concern was resolved.
  class LocalReviewHistory < CommentHistory
    MARKER = 'Earlier review — findings are not automatically resolved. Latest local review:'
    KEY = /\A<!-- shaka:reply:(?:local-adversarial-review|local-review-[0-9a-f]{40}) -->\n/
    SUMMARY = 'Earlier local review'
    ATTESTATION = MergeReviewEvidence::ATTESTATION

    def self.run(arguments, github: nil)
      options = parse_options(arguments)
      return 0 unless options

      github ||= GitHub.new(*arguments)
      result = if options[:ids].empty?
                 new(github).collapse
               else
                 BotReviewHistory.new(github).collapse(options[:ids], head: options[:head])
               end
      publish_result(result)
    end

    def self.parse_options(arguments)
      options = { ids: [] }
      parser = option_parser(options)
      parser.parse!(arguments)
      return nil.tap { puts parser } if options[:help]

      check_options(arguments, options, parser)
      options
    end

    def self.option_parser(options)
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka review collapse OWNER/REPO NUMBER'
        flags.on('-h', '--help') { options[:help] = true }
        flags.on('--bot-comment ID', /\A[1-9]\d*\z/, 'Obsolete bot issue comment; repeat to select several') do |id|
          options[:ids] << id.to_i
        end
        flags.on('--head SHA', /\A[0-9a-f]{40}\z/) { |sha| options[:head] = sha }
      end
    end

    def self.check_options(arguments, options, parser)
      raise OptionParser::InvalidArgument, parser.to_s unless arguments.length == 2
      raise OptionParser::MissingArgument, '--head for --bot-comment' if options[:ids].any? && !options[:head]
      raise OptionParser::InvalidArgument, '--head requires --bot-comment' if options[:head] && options[:ids].empty?
    end

    def self.publish_result(result)
      puts JSON.pretty_generate(result)
      result['unavailable'].empty? ? 0 : 1
    end

    private

    def latest_comment(comments)
      head = @github.api("repos/#{@github.repository}/pulls/#{@github.number}").dig('head', 'sha')
      comments.select { |comment| attestation(comment['body'])[1] == head && active?(comment) }
              .max_by { |comment| order(comment) }
    end

    # A restored head needs its previously archived report republished before it can be current.
    def active?(comment)
      content = comment['body'].split("\n", 2).last.to_s
      content = content.sub(/\A🤖 [^\n]+\n\n/, '')
      !content.start_with?("#{MARKER} ")
    end

    def owned?(comment) = super && !attestation(comment['body'].to_s).nil?

    def earlier?(comment, latest)
      !active?(comment) || attestation(comment['body'])[1] != attestation(latest['body'])[1]
    end

    # Returning to a reviewed head can make its comment older than the existing pointer.
    def keep_pointer?(previous, latest) = previous == latest

    def attestation(body)
      found = body.match(ATTESTATION)
      ReviewerSelection.parse(found[2]) if found
      found
    rescue Error
      nil
    end

    def footer(content) = "\n#{attestation(content)[0].strip}\n"
  end
end
