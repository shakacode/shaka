# frozen_string_literal: true

require 'open3'
require 'tmpdir'

module Shaka
  # Proves a head is exactly a conflict-free merge of a reviewed commit with a newer base.
  #
  # Comparing whole trees covers file modes, binaries, and moved edits, which patch text cannot.
  # The merge runs in a throwaway bare repository that borrows the checkout's objects through
  # `alternates`. It has no config, attributes, or hooks, and system, global, and XDG sources are
  # off, so no merge driver can run: neither one a branch selects through .gitattributes nor one
  # `merge.default` names. Only Git's built-in merge runs, and its objects stay in the throwaway
  # repository. `--attr-source` needs Git 2.40 or later; older Git leaves the proof unavailable.
  class MergeTreeProof
    COMMIT = /\A[0-9a-f]{40}\z/
    EMPTY_TREE = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'
    UNAVAILABLE = 'the commits needed for the proof are not available locally'
    ISOLATED = { 'GIT_CONFIG_NOSYSTEM' => '1', 'GIT_CONFIG_GLOBAL' => File::NULL, 'GIT_ATTR_NOSYSTEM' => '1',
                 'XDG_CONFIG_HOME' => File::NULL, 'GIT_DIR' => nil, 'GIT_OBJECT_DIRECTORY' => nil,
                 'GIT_ALTERNATE_OBJECT_DIRECTORIES' => nil }.freeze

    def initialize(root) = @root = root

    # Returns nil when the proof holds, or why it does not.
    def problem(reviewed:, base:, head:)
      return 'the commits are not full SHAs' unless [reviewed, base, head].all? { |sha| sha.to_s.match?(COMMIT) }

      objects = object_directory
      return UNAVAILABLE unless objects

      Dir.mktmpdir('shaka-merge-proof-') do |scratch|
        @scratch = scratch
        next UNAVAILABLE unless borrow(objects)

        tree_problem(reviewed, base, head)
      end
    end

    private

    def tree_problem(reviewed, base, head)
      merged, status = merged_tree(base, reviewed)
      return 'the reviewed commit does not merge cleanly with the base' if status == 1
      return UNAVAILABLE unless status&.zero? && merged

      head_tree = tree(head)
      return UNAVAILABLE unless head_tree

      'the head differs from a clean merge of the reviewed commit and the base' unless head_tree == merged
    end

    # Reading the checkout's object location runs no merge machinery.
    def object_directory
      output, _error, status = Open3.capture3(ISOLATED, 'git', '-C', @root, 'rev-parse', '--path-format=absolute',
                                              '--git-common-dir')
      File.join(output.strip, 'objects') if status.success? && !output.strip.empty?
    rescue SystemCallError
      nil
    end

    def borrow(objects)
      _output, _error, status = Open3.capture3(ISOLATED, 'git', 'init', '--quiet', '--bare', @scratch)
      return false unless status.success?

      File.write(File.join(@scratch, 'objects', 'info', 'alternates'), "#{objects}\n")
      true
    rescue SystemCallError
      false
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
      Open3.capture3(ISOLATED, 'git', '-C', @scratch, "--attr-source=#{EMPTY_TREE}",
                     '-c', "core.attributesFile=#{File::NULL}", *)
    end
  end
end
