# frozen_string_literal: true

require_relative 'defaults'
require_relative 'error'
require_relative 'configuration/feature_guard'
require_relative 'publication/feature_guard'
require_relative 'publication/review_effort_floor'

module Shaka
  # The highest human review floor a PR may set and still merge without a person confirming its head.
  # The floors come from the changed paths, so an agent cannot argue its own PR into the Auto lane.
  class MergeReviewFloor
    SETTING = 'merge.auto_max_review_floor'
    LEVELS = (1..5)
    DEFAULT = Defaults.fetch('merge', 'auto_max_review_floor')

    def self.validate!(value)
      return if LEVELS.cover?(value) && value.is_a?(Integer)

      raise Error, "#{SETTING} must be a whole number from 1 to 5"
    end

    # seam is the trusted RepositoryConfig; without one the top level applies and nothing is held.
    def self.from(seam, confirmed_head: nil)
      return new(confirmed_head:) unless seam

      new(seam.merge.fetch('auto_max_review_floor'), floors: seam.pr_description['human_review_floors'],
                                                     confirmed_head:)
    end

    # floors are the trusted pr_description.human_review_floors; nil applies the shipped ones.
    # confirmed_head names the head a user approved, as for merge limits.
    def initialize(max = DEFAULT, floors: nil, confirmed_head: nil)
      self.class.validate!(max)
      @max = max
      @floors = floors
      @confirmed_head = confirmed_head
    end

    # At the top level every floor passes, so no file list is read and merging works as before.
    def holds_any? = @max < LEVELS.max

    # Returns why a person must see a PR changing these paths, or nil when Auto may merge it.
    # Shaka's own configuration always goes to a person, whatever floors a repository sets.
    def hold(paths)
      return unless holds_any?

      configuration = paths.find { |path| Configuration::FeatureGuard.configuration?(path) }
      return "#{configuration} changes Shaka's configuration" if configuration

      floor = ReviewEffortFloor.for(paths, @floors)
      return unless floor['level'] > @max

      "#{floor['path']} sets review floor #{floor['level']} (#{floor['reason']}), above #{SETTING} #{@max}"
    end

    def verify!(github, head)
      return if !holds_any? || @confirmed_head == head

      reason = hold(paths(github, head))
      return unless reason

      raise Error, "#{reason}; hand it to the user as Ask, or pass --limits-confirmed-head for a head the " \
                   'user confirmed'
    end

    # GitHub's list follows the live head and base, so both are read on each side of it.
    def paths(github, head)
      pull = pull_at(github, head)
      paths = list(github, pull)
      return paths if pull_at(github, head).dig('base', 'sha') == pull.dig('base', 'sha')

      raise Error, 'PR base moved while its changed files were read; refresh verification and walkthrough'
    end

    private

    def pull_at(github, head)
      pull = github.api("repos/#{github.repository}/pulls/#{github.number}")
      return pull if pull.dig('head', 'sha') == head

      raise Error, 'PR head changed; refresh verification and walkthrough'
    end

    def list(github, pull)
      FeaturePublication.paths(github, pull)
    rescue Error => e
      raise Error, "Cannot read the PR's changed files to check #{SETTING} (#{e.message}); hand it to the user as Ask"
    end
  end
end
