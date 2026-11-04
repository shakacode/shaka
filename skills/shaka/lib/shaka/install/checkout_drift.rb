# frozen_string_literal: true

require 'shellwords'
require_relative 'refusal'

module Shaka
  module Install
    # Recognizes a manual pull of the registered branch and explains any other revision change.
    module CheckoutDrift
      def drifted? = revision != @record['revision'] && !pending?

      private

      # Only an update may record a pull, because it validates the fetched origin tree before advancing.
      def refuse_drift
        return unless @record && drifted?
        return if !release? && @action == :update && pulled?

        raise ArgumentError, drift_message
      end

      # A pull of the registered branch leaves HEAD between the recorded revision and origin.
      def pulled?
        ancestor?(@record['revision'], revision) && ancestor?(revision, "refs/remotes/origin/#{@branch}")
      end

      def ancestor?(older, newer)
        git('merge-base', '--is-ancestor', older, newer)
        true
      rescue ArgumentError
        false
      end

      def drift_message
        detail = "Installation revision changed outside the update procedure (recorded #{@record['revision'][0, 7]}, " \
                 "checkout #{revision[0, 7]})."
        return "#{detail} Release #{@release} must remain at its recorded commit." if release?

        return "#{detail} Run #{Shellwords.escape(helper)} install --update to record it." if pulled?

        "#{detail} It must match #{Refusal.url(@repository)} #{@branch}. Next: #{drift_step}"
      end

      # The same steps install --status gives: catch up a checkout that is behind, or keep local commits on
      # a branch, which an earlier attempt may already have made, and return to the record. reset --keep
      # refuses rather than overwrite an edited file.
      def drift_step
        recorded = @record['revision']
        return Refusal.command('git', '-C', @root, 'merge', '--ff-only', recorded) if ancestor?(revision, recorded)

        name = "kept-#{git('rev-parse', '--short', 'HEAD')}"
        kept = begin
          git('rev-parse', '--verify', '--quiet', "refs/heads/#{name}")
        rescue ArgumentError
          nil
        end
        keep = "#{Refusal.command('git', '-C', @root, 'branch', name)} && " unless kept == revision
        "#{keep}#{Refusal.command('git', '-C', @root, 'reset', '--keep', recorded)}"
      end

      def helper = File.join(@root, 'skills/shaka/scripts/shaka')
    end
  end
end
