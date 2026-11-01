# frozen_string_literal: true

require_relative 'evidence'

module Shaka
  # A separate judgment from the verdict: whether the description's checks prove what its intent rests on.
  # Mixed into the checkpoint publication, which supplies @head, @state, and any @disposition_line.
  module PostImplementationAdequacy
    # The stored verdict keeps its words so published comments still parse. A reader needs to know whose
    # judgment the gaps got, because the maintainer has accepted nothing yet.
    DISPLAYED = { 'adequate with accepted gaps' => 'Adequate, with gaps the reviewer judged acceptable' }.freeze

    private

    def adequacy(report)
      @adequacy = report.fetch('verification_adequacy')
      verdict = @adequacy.fetch('verdict')
      "**Verification:** #{DISPLAYED.fetch(verdict) { verdict.capitalize }}.\n\n" \
        "- Weakest claim: #{@adequacy.fetch('weakest_claim')}\n- Next check: #{@adequacy.fetch('next_check')}"
    end

    # The verdict marker lets merge and the description read the verdict without trusting free text. It sits
    # above the owner's disposition line and the attestation, which close the comment.
    def footer
      verdict = @adequacy && PostImplementationEvidence.adequacy(@adequacy.fetch('verdict'))
      [verdict, @disposition_line].compact.sum('') { "#{it}\n" } + PostImplementationEvidence.attestation(@head, @state)
    end
  end
end
