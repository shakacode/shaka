# frozen_string_literal: true

require 'optparse'
require_relative '../publication/comment_history'

module Shaka
  # Earlier reports retain their findings and their closing merge attestation.
  # A different reviewed commit is history, not proof that any concern was resolved.
  class LocalReviewHistory < CommentHistory
    MARKER = 'Earlier review — findings are not automatically resolved. Latest local review:'
    KEY = /\A<!-- shaka:reply:(?:local-adversarial-review|local-review-[0-9a-f]{40}) -->\n/
    SUMMARY = 'Earlier local review'
    ATTESTATION = %r{^REVIEWED ([0-9a-f]{40}) BY [\w-]+/[\w.-]+ EFFORT \S+ FINDINGS \d+\s*\z}

    def self.run(arguments, github: nil)
      help = false
      parser = OptionParser.new do |flags|
        flags.banner = 'Usage: shaka review collapse OWNER/REPO NUMBER'
        flags.on('-h', '--help') { help = true }
      end
      parser.parse!(arguments)
      return 0.tap { puts parser } if help
      raise OptionParser::InvalidArgument, parser.to_s unless arguments.length == 2

      publish_result(new(github || GitHub.new(*arguments)).collapse)
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

    def attestation(body) = body.match(ATTESTATION)

    def footer(content) = "\n#{attestation(content)[0].strip}\n"
  end
end
