# frozen_string_literal: true

require 'open3'
require_relative 'error'
require_relative 'version'
require_relative 'doctor/installation_identity'

module Shaka
  # Names the workflow code that is running. Every commit between releases shares one
  # VERSION, so the value adds the commit it came from: the revision the managed installer
  # recorded, or the HEAD of the checkout the helper runs from directly. `-modified` marks
  # a copy whose skill files differ from that commit; `-unknown` marks one with no commit.
  # Reading a checkout needs `git`, a Git executable the caller has vetted against the
  # candidate checkout; without one a direct checkout reports `-unknown`.
  module WorkflowVersion
    ROOT = File.expand_path('../../../..', __dir__)
    SKILL = 'skills/shaka'

    module_function

    def current(identity: read_identity, root: ROOT, git: nil)
      identity ||= {}
      "#{identity['version'] || VERSION}-#{commit(identity['source'] || {}, root, git) || 'unknown'}"
    end

    def commit(source, root, git)
      case source['kind']
      when 'revision' then source['revision']
      when 'development' then [source['base_revision'], 'modified'].compact.join('-')
      when 'uninstalled' then git && checkout_commit(root, git)
      end
    end

    def read_identity
      Doctor::InstallationIdentity.read
    rescue Error, KeyError, TypeError, SystemCallError
      nil
    end

    def checkout_commit(root, git)
      return unless run(git, root, 'rev-parse', '--show-toplevel') == File.realpath(root)

      head = run(git, root, 'rev-parse', '--verify', 'HEAD')
      status = run(git, root, 'status', '--porcelain', '--untracked-files=all', '--', SKILL)
      return unless head && status

      status.empty? ? head : "#{head}-modified"
    end

    # Runs from the helper's own directory: a `git` wrapper on PATH may load files relative
    # to its working directory, which is often a candidate checkout.
    def run(git, root, *)
      output, status = Open3.capture2(git, *, chdir: root, err: File::NULL)
      output.strip if status.success?
    rescue Errno::ENOENT
      nil
    end

    private_class_method :read_identity, :commit, :checkout_commit, :run
  end
end
