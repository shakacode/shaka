# frozen_string_literal: true

require 'json'
require 'open3'
require_relative '../error'
require_relative 'destination'

module Shaka
  class BranchHead
    # The tag this worktree won a pickup with, by branch. It lives in the worktree's own Git directory rather than in
    # repository config, which linked worktrees share, so another worktree of the same clone never reads it. The PR's
    # original owner never picked the PR up, so it has none.
    module OwnerTag
      FILE = 'shaka-owner-tags.json'

      module_function

      def recorded(root) = tags(root)[branch(root)]

      def record(root, tag) = write(root, tags(root).merge(branch(root) => tag))

      # Puts back the tag a worktree had before a pickup that did not count; nil removes it.
      def restore(root, tag)
        return record(root, tag) if tag

        write(root, tags(root).except(branch(root)))
      end

      # The checked-out branch, which a pickup requires to be the PR head branch.
      def branch(root) = git(root, 'symbolic-ref', '--quiet', 'HEAD').delete_prefix('refs/heads/')

      def tags(root)
        path = file(root)
        tags = File.exist?(path) ? JSON.parse(File.read(path, encoding: 'UTF-8')) : {}
        raise Error, "#{path} does not hold a JSON object." unless tags.is_a?(Hash)

        tags
      rescue JSON::ParserError => e
        raise Error, "Cannot parse #{path}: #{e.message}"
      end

      def write(root, tags) = File.write(file(root), "#{JSON.pretty_generate(tags)}\n")

      def file(root) = File.join(git(root, 'rev-parse', '--absolute-git-dir'), FILE)

      # Git from outside the checkout, as `shaka branch` runs it, so nothing committed in the checkout runs.
      def git(root, *arguments)
        output, error, status = Open3.capture3(*Destination.runtime(root), '-C', root, *arguments)
        raise Error, "git #{arguments.first} failed: #{error.strip}" unless status.success?

        output.strip
      end
    end
  end
end
