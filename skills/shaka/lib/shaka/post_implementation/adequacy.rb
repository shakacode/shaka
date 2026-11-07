# frozen_string_literal: true

require_relative 'evidence'
require_relative 'risk'

module Shaka
  # A separate judgment from the verdict: whether the description's checks prove what its intent rests on,
  # shown beside the risk rating. Mixed into the checkpoint publication, which supplies @head, @state,
  # @previews, and any @disposition_line.
  module PostImplementationAdequacy
    # The stored verdict keeps its words so published comments still parse. A reader needs to know whose
    # judgment the gaps got, because the maintainer has accepted nothing yet.
    DISPLAYED = { 'adequate with accepted gaps' => 'Adequate, with gaps the reviewer judged acceptable' }.freeze

    private

    def checks(report) = "#{adequacy(report)}\n\n#{risk(report)}"

    # Under review floors the preview and the risk rating can disagree, so the preview says when the rating is
    # meant for a person. Under merge.auto_merge: low the preview already reads the rating.
    def auto_merge_line
      line = @previews[:auto_merge]&.call(verdict: @adequacy&.fetch('verdict'), assessment: @risk_assessment)
      return line unless line && meant_for_person?

      "#{line} The risk rating above is #{@risk_assessment.fetch('level')}, which is meant for a person to merge."
    end

    def meant_for_person?
      @risk_assessment && !@risk_assessment['governs'] && @risk_assessment.fetch('level') != 'low'
    end

    # Without a risk preview, as in a test, changed files count as unread and the rating as high.
    def risk(report)
      rating = report.fetch('risk')
      rate = @previews[:risk] || ->(value) { PostImplementationRisk.assess(value, {}, nil) }
      @risk_assessment = rate.call(rating.fetch('rating'))
      PostImplementationRisk.section(@risk_assessment, rating.fetch('reasons'))
    end

    def adequacy(report)
      @adequacy = report.fetch('verification_adequacy')
      verdict = @adequacy.fetch('verdict')
      "**Verification:** #{DISPLAYED.fetch(verdict) { verdict.capitalize }}.\n\n" \
        "- Weakest claim: #{@adequacy.fetch('weakest_claim')}\n- Next check: #{@adequacy.fetch('next_check')}"
    end

    # The rating and verdict markers let merge and the description read them without trusting free text. They
    # sit above the owner's disposition line and the attestation, which close the comment.
    def footer
      verdict = @adequacy && PostImplementationEvidence.adequacy(@adequacy.fetch('verdict'))
      rating = verdict && @risk_assessment && PostImplementationEvidence.risk(@risk_assessment.fetch('rating'))
      [rating, verdict, @disposition_line].compact.sum('') { "#{it}\n" } +
        PostImplementationEvidence.attestation(@head, @state)
    end
  end
end
