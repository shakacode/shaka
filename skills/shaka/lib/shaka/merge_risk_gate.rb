# frozen_string_literal: true

require_relative 'error'
require_relative 'pull_changed_files'
require_relative 'repository_config/high_risk_areas_schema'
require_relative 'post_implementation/risk'

module Shaka
  # Under merge.auto_merge_max_risk, the agent may merge only a head its checkpoint rated at that level or
  # lower, with no changed file in a high-risk area or in Shaka's own configuration. The rating comes from this
  # account's checkpoint marker for the exact head; the areas come from the trusted settings and the files from
  # GitHub, so a PR cannot lower either.
  class MergeRiskGate
    SETTING = 'merge.auto_merge_max_risk'

    def self.max_risk(seam) = PostImplementationRisk.max_risk(seam)

    # seam is the trusted RepositoryConfig, or nil when there is none, which applies the packaged level and
    # areas; checkpoint answers risk(head) with the published rating or nil. confirmed_head names the head a
    # user approved, as for merge limits.
    def initialize(seam, checkpoint, confirmed_head: nil)
      @seam = seam
      @areas, @medium = PostImplementationRisk.areas(seam)
      @checkpoint = checkpoint
      @confirmed_head = confirmed_head
      @max_risk = self.class.max_risk(seam)
    end

    def verify!(github, head)
      return if @confirmed_head == head

      reason = hold(github, head)
      return unless reason

      raise Error, "#{reason}, and #{SETTING}: #{@max_risk} lets the agent merge only " \
                   "#{PostImplementationRisk.allowed(@max_risk)} risk; hand it to the user as Ask, or pass " \
                   '--limits-confirmed-head for a head the user confirmed'
    end

    # A retired floor below 5 kept files from Auto that the risk areas may not name yet, so it holds every merge.
    def self.retired(seam)
      floor = seam.respond_to?(:retired_floor) && seam.retired_floor
      return unless floor

      "this repository still sets the retired merge.auto_max_review_floor: #{floor}; move the paths its floors " \
        'held into high_risk_areas or medium_risk_areas, then remove it'
    end

    # Returns why a person must merge this head, or nil when its rating and files allow Auto.
    def hold(github, head)
      retired = self.class.retired(@seam)
      return retired if retired

      rating = @checkpoint.risk(head)
      assessment = PostImplementationRisk.assess(rating || 'unknown', @areas, read(github, head), @medium)
      self.class.reason(assessment, @max_risk, rating)
    end

    # Shared with the Auto merge preview, so the checkpoint names the reason merge would give.
    def self.reason(assessment, max_risk, rating = assessment['rating'])
      return if PostImplementationRisk.within?(assessment['level'], max_risk)
      return 'the checkpoint for this head has no risk rating' unless rating
      return "Shaka could not read this PR's changed files" unless assessment['paths_read']

      # The PR's author names its files, and the preview publishes this line under the maintainer's account.
      hit = assessment['areas_hit'].first
      return "`#{PostImplementationRisk.inert(hit['path'])}` is in high-risk area `#{hit['area']}`" if hit

      raised = assessment.fetch('medium_areas_hit', []).first
      return "`#{PostImplementationRisk.inert(raised['path'])}` is in medium-risk area `#{raised['area']}`" if raised

      "the checkpoint rates this head #{assessment['level']} risk"
    end

    private

    def read(github, head)
      PullChangedFiles.new.paths(github, head)
    rescue PullChangedFiles::Moved
      raise
    rescue Error, SystemCallError
      nil
    end
  end
end
