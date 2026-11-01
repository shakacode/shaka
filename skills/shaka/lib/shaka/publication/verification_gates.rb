# frozen_string_literal: true

module Shaka
  # Writes the repository validation and local review line from their bound results, so no
  # check has to restate them and no paraphrase can call a failed run a pass.
  module VerificationGates
    LABEL = '**Validation and review:**'
    UNKNOWN = "#{LABEL} UNKNOWN: no validation or review results were supplied for this revision.".freeze
    GAPS = '**Setup gaps:**'
    # Verification reaches ready without a review only when the trusted review.required is none.
    NOT_REQUIRED = 'review not required by this repository’s settings'
    CONTAINER_GUIDE = 'https://github.com/shakacode/shaka/blob/main/docs/settings.md#run-codex-reviews-in-a-container'

    module_function

    # A reader needs to see a failure, a missing result, fewer reviewers than configured, or a
    # reviewer that read only the diff; a routine run folds behind its summary. A completed review
    # may still have reported findings, so the summary claims only that it ran.
    def render(verdict, review_url = nil, shortfall = nil)
      blind = blind_reviewers(verdict)
      folded = shortfall.nil? && blind.empty? && routine?(verdict)
      text = folded ? summary(verdict, review_url) : line(verdict, review_url)
      gaps = setup_gaps(shortfall, blind, review_url)
      gaps ? "#{text}\n\n#{gaps}" : text
    end

    def summary(verdict, url)
      text = "Validation passed; local review completed at #{short_head(verdict)}"
      url ? "#{text} ([evidence](#{url}))." : "#{text}."
    end

    # Binding accepts a completed run whatever its exit, so the exit code decides the wording here.
    def line(verdict, review_url = nil)
      return UNKNOWN unless verdict

      validation, reviews = results(verdict)
      reviewed = reviews.empty? && verdict['review_required'] == false ? NOT_REQUIRED : review(reviews, review_url)
      "#{LABEL} #{[*validations(validation), reviewed].join('; ')} at `#{short_head(verdict)}`."
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

    def setup_gaps(shortfall, blind, url)
      gaps = [(reviewer_gap(shortfall, url) if shortfall), (blind_gap(blind) if blind.any?)].compact
      "#{GAPS} #{gaps.join(' ')}" unless gaps.empty?
    end

    # A Codex reviewer whose sandbox refused every command, as in a container without user
    # namespaces, answered from the diff in its prompt alone. Only a run of that reviewer whose
    # sandbox ran a command clears it; a run that issued none shows nothing about the sandbox.
    def blind_reviewers(verdict)
      return [] unless verdict

      reviews = results(verdict).last.group_by { |result| result['reviewer'] }
      reviews.filter_map { |reviewer, runs| reviewer if blind?(runs.map { |result| result['commands'] }) }
    end

    # Runs that recorded commands decide, and each of them must have had every command refused.
    def blind?(summaries)
      counted = summaries.select { |commands| commands.is_a?(Hash) && commands['ran'].to_i.positive? }
      counted.any? && counted.all? { |commands| commands['sandbox_failed'].to_i == commands['ran'].to_i }
    end

    def blind_gap(reviewers)
      names = reviewers.map { |name| "`#{name}`" }.join(', ')
      who, own = reviewers.one? ? %w[it its] : %w[they their]
      "#{names} could not start #{own} sandbox, so #{who} reviewed only the diff ([why](#{CONTAINER_GUIDE}))."
    end

    # The review comment holds each reviewer's rounds and any gap or fallback notice.
    def reviewer_gap(shortfall, url)
      text = "#{shortfall['completed']} of #{shortfall['configured']} configured reviewers completed"
      missing = shortfall['missing'].map { |provider| "`#{provider}`" }
      text += "; #{missing.join(', ')} did not" unless missing.empty?
      url ? "#{text} ([review comment](#{url}))." : "#{text}."
    end

    # A host review is only reported by its attestation; a CLI review was launched by the helper.
    def review(results, url)
      reviewers = results.map do |result|
        result['status'] == 'reported' ? "#{result['reviewer']} (host-reported)" : result['reviewer']
      end
      text = "local review by #{reviewers.join(', ')}"
      url ? "#{text} ([attestation](#{url}))" : text
    end

    private_class_method :routine?, :summary, :short_head, :results, :validations,
                         :setup_gaps, :blind_reviewers, :blind?, :blind_gap, :reviewer_gap, :review
  end
end
