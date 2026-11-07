# frozen_string_literal: true

require_relative 'error'
require_relative 'merge_review_floor'
require_relative 'post_implementation/risk'

module Shaka
  # Under merge.auto_merge: low, the agent may merge only a head its checkpoint rated low risk, with no
  # changed file in a high-risk area or in Shaka's own configuration. The rating comes from this account's
  # checkpoint marker for the exact head; the areas come from the trusted settings and the files from GitHub,
  # so a PR cannot lower either.
  class MergeRiskGate
    SETTING = 'merge.auto_merge'

    # seam is the trusted RepositoryConfig; checkpoint answers risk(head) with the published rating or nil.
    # confirmed_head names the head a user approved, as for merge limits.
    def initialize(seam, checkpoint, confirmed_head: nil)
      @seam = seam
      @checkpoint = checkpoint
      @confirmed_head = confirmed_head
    end

    def verify!(github, head)
      return if @confirmed_head == head

      reason = hold(github, head)
      return unless reason

      raise Error, "#{reason}, and #{SETTING}: low lets the agent merge only low risk; hand it to the user as " \
                   'Ask, or pass --limits-confirmed-head for a head the user confirmed'
    end

    # Returns why a person must merge this head, or nil when its rating and files allow Auto.
    def hold(github, head)
      rating = @checkpoint.risk(head)
      assessment = PostImplementationRisk.assess(rating || 'unknown', @seam.high_risk_areas, read(github, head))
      self.class.reason(assessment, rating)
    end

    # Shared with the Auto merge preview, so the checkpoint names the reason merge would give.
    def self.reason(assessment, rating = assessment['rating'])
      return if assessment['level'] == 'low'
      return 'the checkpoint for this head has no risk rating' unless rating
      return "Shaka could not read this PR's changed files" unless assessment['paths_read']

      # The PR's author names its files, and the preview publishes this line under the maintainer's account.
      hit = assessment['areas_hit'].first
      return "`#{PostImplementationRisk.inert(hit['path'])}` is in high-risk area `#{hit['area']}`" if hit

      "the checkpoint rates this head #{assessment['level']} risk"
    end

    private

    def read(github, head)
      MergeReviewFloor.new.paths(github, head)
    rescue Error, SystemCallError
      nil
    end
  end
end
