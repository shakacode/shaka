# frozen_string_literal: true

require_relative '../merge_tree_proof'
require_relative 'check'

module Shaka
  class Doctor
    # Reports whether this machine's Git is new enough for merge's rebase proof.
    #
    # Below the minimum only that proof stops working, so an older Git degrades the start
    # rather than blocking it.
    class GitRuntime
      include Check

      MINIMUM = MergeTreeProof::MINIMUM_GIT.join('.')

      def initialize(runner) = @runner = runner

      def call
        out, error, ok = @runner.call(%w[git version])
        return missing(error) unless ok
        return check('Git', 'healthy', first_line(out)) if MergeTreeProof.supported_git?(out)

        check('Git', 'degraded',
              "#{first_line(out)} is older than #{MINIMUM}, so merge cannot accept a review of an earlier " \
              'commit after the base moves; that PR needs a fresh review or a waiver',
              guidance: "Install Git #{MINIMUM} or newer, then rerun doctor.")
      end

      private

      def missing(error)
        check('Git', 'failed', "git does not run: #{first_line(error)}",
              guidance: "Install Git #{MINIMUM} or newer from https://git-scm.com/downloads.")
      end
    end
  end
end
