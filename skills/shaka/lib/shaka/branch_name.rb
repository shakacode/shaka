# frozen_string_literal: true

require 'open3'
require_relative 'error'

module Shaka
  # Asks Git whether a configured or requested branch name unambiguously names a branch.
  #
  # Git owns the ref-name rules, so this shells out rather than approximating them in Ruby.
  # Three things Git accepts are still not a branch a caller can name. Shorthand such as
  # `@{-1}` resolves to a commit; requiring the normalized output to equal the input catches
  # it. A qualified `refs/heads/main` names a ref rather than the branch GitHub targets. And
  # a name that collides with one of Git's own root refs resolves to that ref wherever a
  # revision is expected, so `git diff FETCH_HEAD...HEAD` would compare against something
  # other than the branch. Root refs are `@` and the unslashed all-uppercase names Git keeps
  # directly in the Git directory, so matching that shape rejects `HEAD`, `MERGE_AUTOSTASH`,
  # and whatever Git adds next without a list to keep current. The cost is a top-level branch
  # named `RELEASE`, which is ambiguous for the same reason.
  module BranchName
    QUALIFIED = %r{\Arefs/}
    ROOT_REF = /\A(?:@|[A-Z][A-Z0-9_]*)\z/

    def self.explicit!(value, label:, root:)
      raise Error, "#{label} must be a non-empty string" unless value.is_a?(String) && !value.strip.empty?
      raise Error, "#{label} must be a branch name, not a qualified ref" if value.match?(QUALIFIED)
      raise Error, "#{label} must be a branch name, not a Git root ref" if value.match?(ROOT_REF)

      output, _error, status = Open3.capture3('git', '-C', root, 'check-ref-format', '--branch', value)
      raise Error, "#{label} must be a valid Git branch name" unless status.success?
      raise Error, "#{label} must be an explicit branch name" unless output.strip == value

      output.strip
    end
  end
end
