# frozen_string_literal: true

require_relative 'error'
require_relative 'publication/feature_guard'

module Shaka
  # The PR's changed files for one exact head, both names of a rename. The merge risk gate and the checkpoint's
  # risk rating read them, so a file in a high-risk area cannot pass unseen.
  class PullChangedFiles
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
      raise Error, "Cannot read the PR's changed files (#{e.message}); hand it to the user as Ask"
    end
  end
end
