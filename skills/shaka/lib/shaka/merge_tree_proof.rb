# frozen_string_literal: true

require 'open3'

module Shaka
  # Proves a head is exactly a conflict-free merge of a reviewed commit with a newer base.
  #
  # `git merge-tree --write-tree` merges in memory and writes unreferenced objects that `git gc`
  # prunes. Comparing whole trees covers file modes, binaries, and moved edits, which patch text
  # cannot. The branch could select a configured merge driver through .gitattributes, so the proof
  # reads attributes from the empty tree (`--attr-source`, Git 2.40+) and ignores the user's
  # attributes file; only Git's built-in merge runs.
  class MergeTreeProof
    COMMIT = /\A[0-9a-f]{40}\z/
    EMPTY_TREE = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'

    def initialize(root) = @root = root

    # Returns nil when the proof holds, or why it does not.
    def problem(reviewed:, base:, head:)
      return 'the commits are not full SHAs' unless [reviewed, base, head].all? { |sha| sha.to_s.match?(COMMIT) }

      tree_problem(reviewed, base, head)
    end

    private

    def tree_problem(reviewed, base, head)
      merged, status = merged_tree(base, reviewed)
      return 'the reviewed commit does not merge cleanly with the base' if status == 1
      return 'the commits needed for the proof are not available locally' unless status&.zero? && merged

      head_tree = tree(head)
      return 'the commits needed for the proof are not available locally' unless head_tree

      'the head differs from a clean merge of the reviewed commit and the base' unless head_tree == merged
    end

    # Exit 0 is a clean merge and 1 a conflict; anything else means the objects or Git are unusable.
    def merged_tree(base, reviewed)
      output, _error, status = git('merge-tree', '--write-tree', '--no-messages', base, reviewed)
      [output.lines.first&.strip, status.exitstatus]
    rescue SystemCallError
      [nil, nil]
    end

    def tree(commit)
      output, _error, status = git('rev-parse', '--verify', '--quiet', '--end-of-options', "#{commit}^{tree}")
      output.strip if status.success?
    rescue SystemCallError
      nil
    end

    def git(*)
      Open3.capture3('git', '-C', @root, "--attr-source=#{EMPTY_TREE}", '-c', 'core.attributesFile=/dev/null', *)
    end
  end
end
