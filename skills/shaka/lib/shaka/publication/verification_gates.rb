# frozen_string_literal: true

require_relative 'human_comments'

module Shaka
  # Writes the repository validation and local review line from their bound results, so no
  # check has to restate them and no paraphrase can call a failed run a pass.
  module VerificationGates
    LABEL = '**Validation and review:**'
    UNKNOWN = "#{LABEL} UNKNOWN: no validation or review results were supplied for this revision.".freeze
    GAPS = '**Setup gaps:**'
    # GitHub's author_association values for the owner, organization members, and collaborators.
    INSIDERS = %w[OWNER MEMBER COLLABORATOR].freeze

    module_function

    # A reader needs to see a failure, a missing result, or fewer reviewers than configured; a routine
    # run folds behind its summary. A completed review may still have reported findings, so the
    # summary claims only that it ran. unlabeled counts the PR author's comments with no identity
    # line or marker; it adds a Setup gaps line but says nothing about the run, so the run stays folded.
    def render(verdict, review_url = nil, shortfall = nil, unlabeled = 0)
      text = shortfall || !routine?(verdict) ? line(verdict, review_url) : summary(verdict, review_url)
      gaps = setup_gaps(shortfall, unlabeled, review_url)
      gaps ? "#{text}\n\n#{gaps}" : text
    end

    def summary(verdict, url)
      text = "Validation passed; local review completed at #{short_head(verdict)}"
      url ? "#{text} ([evidence](#{url}))." : "#{text}."
    end

    # Comments read at this head that are the author's by login, yet carry no agent identity line or
    # marker. The count holds whether or not the repository shows the comment list. An agent posts
    # from an account GitHub lists as the owner, an organization member, or a collaborator, so an
    # outside contributor's comments, their own words, do not count; nor does an unlisted author.
    def unlabeled(content, pull)
      packet = content[HumanComments::KEY]
      author = pull&.dig('user', 'login')
      return 0 unless author.is_a?(String) && insider?(pull) && read_at?(packet, pull.dig('head', 'sha'))

      HumanCommentEntries.new(packet).humans.count { |entry| !entry.unverified && entry.login.casecmp?(author) }
    end

    def insider?(pull) = INSIDERS.include?(pull['author_association'])

    # A read without a head, or taken at another head, may count comments relabeled since.
    def read_at?(packet, head) = packet.is_a?(Hash) && packet['head'].is_a?(String) && packet['head'] == head

    # Binding accepts a completed run whatever its exit, so the exit code decides the wording here.
    def line(verdict, review_url = nil)
      return UNKNOWN unless verdict

      validation, reviews = results(verdict)
      "#{LABEL} #{[*validations(validation), review(reviews, review_url)].join('; ')} at `#{short_head(verdict)}`."
    end

    # Only a ready verdict reaches publication. A host-reported review rests on its attestation
    # alone, so it stays visible with the reviewers' names.
    def routine?(verdict)
      return false unless verdict

      validation, reviews = results(verdict)
      validation.map { |result| result['exit_code'] }.uniq == [0] &&
        reviews.map { |result| result['status'] }.uniq == ['completed']
    end

    def short_head(verdict) = verdict['head'][0, 7]

    def results(verdict)
      %w[validation review].map do |kind|
        Array(verdict.dig('checks', kind)).map { |entry| entry['original'] }
      end
    end

    def validations(results)
      results.map do |result|
        code = result['exit_code']
        "`#{result['command']}` #{code&.zero? ? 'passed' : 'failed'} (exit #{code})"
      end
    end

    def setup_gaps(shortfall, unlabeled, url)
      gaps = [(reviewer_gap(shortfall, url) if shortfall), (unlabeled_gap(unlabeled) if unlabeled.positive?)]
      "#{GAPS} #{gaps.compact.join(' ')}" if gaps.any?
    end

    # The review comment holds each reviewer's rounds and any gap or fallback notice.
    def reviewer_gap(shortfall, url)
      text = "#{shortfall['completed']} of #{shortfall['configured']} configured reviewers completed"
      missing = shortfall['missing'].map { |provider| "`#{provider}`" }
      text += "; #{missing.join(', ')} did not" unless missing.empty?
      url ? "#{text} ([review comment](#{url}))." : "#{text}."
    end

    # An agent posts under the author's login, so its reply without the identity line reads as theirs.
    def unlabeled_gap(count)
      return '1 comment from the PR author has no AI identity line; if an agent wrote it, add the line.' if count == 1

      "#{count} comments from the PR author have no AI identity line; if an agent wrote them, add the line."
    end

    # A host review is only reported by its attestation; a CLI review was launched by the helper.
    def review(results, url)
      reviewers = results.map do |result|
        result['status'] == 'reported' ? "#{result['reviewer']} (host-reported)" : result['reviewer']
      end
      text = "local review by #{reviewers.join(', ')}"
      url ? "#{text} ([attestation](#{url}))" : text
    end

    private_class_method :insider?, :read_at?, :routine?, :summary, :short_head, :results, :validations,
                         :setup_gaps, :reviewer_gap, :unlabeled_gap, :review
  end
end
