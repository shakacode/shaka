# frozen_string_literal: true

require_relative '../error'
require_relative '../post_implementation_report'
require_relative 'history'
require_relative 'published_risk'

module Shaka
  # Checks this account's published checkpoint facts, not the reviewer's product judgment.
  class PostImplementationEvidence
    MARK = 'shaka:post-implementation'
    ATTESTATION = /\n<!-- #{MARK} ([0-9a-f]{40}) (ready|blocked|opted_out|not_completed) -->\s*\z/

    def self.attestation(head, state) = "<!-- #{MARK} #{head} #{state} -->"

    # The owner's disposition sits on the line directly above the attestation, so free text earlier in the
    # report cannot plant one, and it counts only when it agrees with the attested state.
    RECOMMENDATION = PostImplementationReport::RECOMMENDATIONS.join('|')
    DISPOSITION = Regexp.new("\n<!-- #{MARK}-disposition (#{RECOMMENDATION}) -->" \
                             "\n<!-- #{MARK} ([0-9a-f]{40}) (ready|blocked) -->\\s*\\z")
    def self.disposition(recommendation) = "<!-- #{MARK}-disposition #{recommendation} -->"

    # The reviewer's verification verdict sits above those lines for the same reason.
    ADEQUACY_SLUGS = PostImplementationReport::ADEQUACY.to_h { |verdict| [verdict.tr(' ', '_'), verdict] }.freeze
    ADEQUACY = Regexp.new("\n<!-- #{MARK}-adequacy (#{ADEQUACY_SLUGS.keys.join('|')}) -->" \
                          "\n(?:<!-- #{MARK}-disposition (?:#{RECOMMENDATION}) -->\n)?" \
                          "<!-- #{MARK} ([0-9a-f]{40}) (?:ready|blocked) -->\\s*\\z")
    def self.adequacy(verdict) = "<!-- #{MARK}-adequacy #{verdict.tr(' ', '_')} -->"

    # The reviewer's risk rating sits directly above the verdict, so merge can read it under merge.auto_merge_max_risk.
    RISK = Regexp.new("\n<!-- #{MARK}-risk (#{PostImplementationReport::RISK.join('|')}) -->" \
                      "\n<!-- #{MARK}-adequacy (?:#{ADEQUACY_SLUGS.keys.join('|')}) -->" \
                      "\n(?:<!-- #{MARK}-disposition (?:#{RECOMMENDATION}) -->\n)?" \
                      "<!-- #{MARK} ([0-9a-f]{40}) (ready|blocked) -->\\s*\\z")
    def self.risk(rating) = "<!-- #{MARK}-risk #{rating} -->"

    def initialize(github, enabled: true)
      @github = github
      @enabled = enabled
    end

    def call(head)
      return { 'basis' => 'trusted_opt_out' } if @enabled == false

      comment = latest
      reviewed, state = comment&.fetch('body', '').to_s.match(ATTESTATION)&.captures
      unless reviewed == head && %w[ready opted_out].include?(state)
        raise Error, "Checkpoint is missing, stale, or blocked for #{head}; " \
                     'run and publish the checkpoint for this head before final preparation.'
      end

      { 'basis' => state, 'head' => reviewed, 'comment' => comment['html_url'],
        'verification_adequacy' => adequacy_in(comment, head) }.compact
    end

    # The latest checkpoint's verification verdict, or nil when that checkpoint is for another head or has none.
    def adequacy(head) = adequacy_in(latest, head)

    # The latest checkpoint's risk rating, or nil when that checkpoint is for another head, is blocked, or has none.
    def risk(head)
      rating, reviewed, state = latest&.fetch('body', '').to_s.match(RISK)&.captures
      rating if reviewed == head && state == 'ready'
    end

    # What the latest checkpoint printed about risk for this head, ready or blocked, since a blocked checkpoint
    # still shows its rating: the rating, the reviewer's reasons, and the comment's link. Nil for another head or
    # a checkpoint without a rating. Merge reads risk(head), which requires a ready checkpoint.
    def published_risk(head)
      comment = latest
      return unless comment

      body = comment.fetch('body', '').to_s
      rating, reviewed = body.match(RISK)&.captures
      return unless rating && reviewed == head

      reasons = PostImplementationPublishedRisk.reasons_in(body)
      { 'rating' => rating, 'reasons' => reasons, 'url' => comment['html_url'] }
    end

    # The latest checkpoint's owner recommendation, or nil when that checkpoint is for another head or has none.
    def recommendation(head)
      recommendation, reviewed, state = latest&.fetch('body', '').to_s.match(DISPOSITION)&.captures
      recommendation if reviewed == head && (recommendation == 'Merge') == (state == 'ready')
    end

    private

    def adequacy_in(comment, head)
      slug, reviewed = comment&.fetch('body', '').to_s.match(ADEQUACY)&.captures
      ADEQUACY_SLUGS[slug] if reviewed == head
    end

    def latest
      account = @github.viewer_login
      checkpoints = @github.issue_comments.select do |entry|
        entry.dig('user', 'login') == account && entry['body'].to_s.match?(PostImplementationHistory::KEY)
      end
      checkpoints.max_by { |entry| CommentHistory.order(entry) }
    end
  end
end
