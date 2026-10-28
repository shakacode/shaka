# frozen_string_literal: true

module Shaka
  # Writes the repository validation and local review line from their bound results, so no
  # check has to restate them and no paraphrase can call a failed run a pass.
  module VerificationGates
    LABEL = '**Validation and review:**'
    UNKNOWN = "#{LABEL} UNKNOWN: no validation or review results were supplied for this revision.".freeze
    GAPS = '**Setup gaps:**'

    module_function

    # A reader needs to see a failure, a missing result, or fewer reviewers than configured; a routine
    # run folds behind its summary. A completed review may still have reported findings, so the
    # summary claims only that it ran.
    def render(verdict, review_url = nil, shortfall = nil)
      text = line(verdict, review_url)
      return "#{text}\n\n#{setup_gaps(shortfall, review_url)}" if shortfall
      return text unless routine?(verdict)

      summary = "Validation passed; local review completed at #{short_head(verdict)}"
      review_url ? "#{summary} ([evidence](#{review_url}))." : "#{summary}."
    end

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

    # The review comment holds each reviewer's rounds and any gap or fallback notice.
    def setup_gaps(shortfall, url)
      text = "#{GAPS} #{shortfall['completed']} of #{shortfall['configured']} configured reviewers completed"
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

    private_class_method :routine?, :short_head, :results, :validations, :setup_gaps, :review
  end
end
