# frozen_string_literal: true

require 'open3'
require_relative 'error'
require_relative 'version'
require_relative 'doctor/installation_identity'

module Shaka
  # Names the workflow code that is running. Every commit between releases shares one
  # VERSION, so the commit identifies the code: the revision the managed installer recorded,
  # or the HEAD of the checkout the helper runs from directly. `modified` marks a copy whose
  # skill files differ from that commit. Reading a checkout needs `git`, a Git executable
  # the caller has vetted against the candidate checkout; without one the commit is unknown.
  module WorkflowVersion
    ROOT = File.expand_path('../../../..', __dir__)
    SKILL = 'skills/shaka'
    # Inherited from a Git hook or wrapper, these would point Git at another repository.
    GIT_ENVIRONMENT = %w[GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_PREFIX]
                      .to_h { |name| [name, nil] }.freeze

    REPOSITORY = 'https://github.com/shakacode/shaka'
    COMMIT = /\A(?:\h{40}|\h{64})\z/
    RELEASE = /\A[A-Za-z0-9][A-Za-z0-9._-]{0,39}\z/

    # Renders a linked commit, or the release version when no commit is known. Installation
    # metadata is only type-checked, so each part is checked before it reaches the table.
    Result = Data.define(:version, :commit, :modified) do
      def markdown
        return "#{link}#{' (modified)' if modified}" if commit

        raise Error, 'Workflow version is invalid.' unless version.is_a?(String) && version.match?(RELEASE)

        "`#{version}` (commit unknown#{', modified' if modified})"
      end

      private

      def link
        raise Error, 'Workflow commit is invalid.' unless commit.is_a?(String) && commit.match?(COMMIT)

        "[`#{commit[0, 7]}`](#{REPOSITORY}/commit/#{commit})"
      end
    end

    module_function

    def current(identity: read_identity, root: ROOT, git: nil)
      identity ||= {}
      source = identity['source'] || {}
      commit, modified = commit(source, root, git)
      Result.new(version: identity['version'] || VERSION, commit:, modified: modified || false)
    end

    def commit(source, root, git)
      case source['kind']
      when 'revision' then [source['revision'], false]
      when 'development' then [source['base_revision'], true]
      when 'uninstalled' then git ? checkout_commit(root, git) : [nil, false]
      else [nil, false]
      end
    end

    def read_identity
      Doctor::InstallationIdentity.read
    rescue Error, KeyError, TypeError, SystemCallError
      nil
    end

    def checkout_commit(root, git)
      return [nil, false] unless run(git, root, 'rev-parse', '--show-toplevel') == File.realpath(root)

      head = run(git, root, 'rev-parse', '--verify', 'HEAD')
      status = run(git, root, 'status', '--porcelain', '--untracked-files=all', '--', SKILL)
      entries = run(git, root, 'ls-files', '-v', '--', SKILL)
      return [nil, false] unless head && status && entries

      [head, !status.empty? || index_flags?(entries)]
    end

    # `git status` hides edits to assume-unchanged (lowercase tag) and skip-worktree (`S`)
    # files, so any tag other than a plain cached `H` means status cannot vouch for them.
    def index_flags?(entries) = entries.lines.any? { |line| !line.start_with?('H ') }

    # Runs from the helper's own directory: a `git` wrapper on PATH may load files relative
    # to its working directory, which is often a candidate checkout.
    def run(git, root, *)
      output, status = Open3.capture2(GIT_ENVIRONMENT, git, *, chdir: root, err: File::NULL)
      output.strip if status.success?
    rescue Errno::ENOENT
      nil
    end

    private_class_method :read_identity, :commit, :checkout_commit, :index_flags?, :run
  end
end
