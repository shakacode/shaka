# frozen_string_literal: true

require 'open3'
require_relative '../error'
require_relative 'destination'

module Shaka
  class BranchHead
    # The tag this checkout won a pickup with, kept in its branch config beside the accepted head. The PR's original
    # owner never picked it up, so it has none.
    module OwnerTag
      module_function

      def recorded(root)
        output, error, status = config(root, '--get', key(root))
        return output.strip if status.success?
        return if status.exitstatus == 1

        raise Error, "Cannot read #{key(root)}: #{error.strip}"
      end

      def record(root, tag)
        _output, error, status = config(root, key(root), tag)
        raise Error, "Cannot record #{key(root)}: #{error.strip}" unless status.success?
      end

      # Puts back the tag a checkout had before a pickup that did not count; nil removes it.
      def restore(root, tag)
        return record(root, tag) if tag

        _output, error, status = config(root, '--unset-all', key(root))
        raise Error, "Cannot clear #{key(root)}: #{error.strip}" unless status.success? || status.exitstatus == 5
      end

      # The checked-out branch, which `branch check` requires to be the PR head branch.
      def branch(root)
        output, error, status = git(root, 'symbolic-ref', '--quiet', 'HEAD')
        raise Error, "No branch is checked out: #{error.strip}" unless status.success?

        output.strip.delete_prefix('refs/heads/')
      end

      def key(root) = "branch.#{branch(root)}.shakaOwnerTag"

      def config(root, *) = git(root, 'config', '--local', *)

      # Git from outside the checkout, as `shaka branch` runs it, so nothing committed in the checkout runs.
      def git(root, *) = Open3.capture3(*Destination.runtime(root), '-C', root, *)
    end
  end
end
