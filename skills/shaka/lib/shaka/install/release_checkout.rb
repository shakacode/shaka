# frozen_string_literal: true

module Shaka
  module Install
    # A release stays at its first resolved commit; changing versions requires another checkout.
    module ReleaseCheckout
      VERSION = /\A[0-9]+\.[0-9]+\.[0-9]+(?:[.-][A-Za-z0-9]+)*\z/

      def self.reference(record)
        record['release'] ? "refs/tags/v#{record['release']}" : record.fetch('branch')
      end

      def release? = !@release.nil?

      private

      def release_ref = "refs/tags/v#{@release}"

      def validate_release
        raise ArgumentError, 'Choose a branch or a release, not both' if @branch
        if @record && @record['release'] != @release
          raise ArgumentError, 'Install a different release in a new directory with --take-over'
        end
        raise ArgumentError, 'Release checkout must have a detached HEAD' unless git('branch', '--show-current').empty?
        raise ArgumentError, 'Release tag differs from the installed revision' unless
          git('rev-parse', "#{release_ref}^{commit}") == revision

        actual = Version.read(File.join(@root, 'skills/shaka/lib/shaka/version.rb'))
        return if actual == @release

        raise ArgumentError, "Release version mismatch: requested #{@release}, found #{actual}"
      end

      def check_release
        remote = git('ls-remote', '--exit-code', 'origin', release_ref, "#{release_ref}^{}")
        refs = remote.lines.to_h { |line| line.split.reverse }
        resolved = refs["#{release_ref}^{}"] || refs[release_ref]
        raise ArgumentError, 'Release tag changed remotely; keep this installation and investigate' unless
          resolved == @record.fetch('revision')
      end

      def clone_release
        git('clone', '--quiet', '--no-checkout', '--branch', "v#{@release}", '--', @repository, @root)
        # A branch named vVERSION must never stand in for the release tag.
        git('checkout', '--quiet', '--detach', release_ref)
      end
    end
  end
end
