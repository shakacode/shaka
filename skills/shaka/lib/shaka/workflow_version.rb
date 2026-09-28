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
  module WorkflowVersion
    ROOT = File.expand_path('../../../..', __dir__)
    SKILL = 'skills/shaka'

    module_function

    def current(identity: read_identity, root: ROOT)
      source = identity&.fetch('source', nil) || {}
      version = identity&.fetch('version', nil) || VERSION
      commit = case source['kind']
               when 'revision' then source['revision']
               when 'development' then [source['base_revision'], 'modified'].compact.join('-')
               when 'uninstalled' then checkout_commit(root)
               end
      "#{version}-#{commit || 'unknown'}"
    end

    def read_identity
      Doctor::InstallationIdentity.read
    rescue Error, KeyError, TypeError, SystemCallError
      nil
    end

    def checkout_commit(root)
      return unless git(root, 'rev-parse', '--show-toplevel') == File.realpath(root)

      head = git(root, 'rev-parse', '--verify', 'HEAD')
      status = git(root, 'status', '--porcelain', '--untracked-files=all', '--', SKILL)
      return unless head && status

      status.empty? ? head : "#{head}-modified"
    end

    def git(root, *)
      output, status = Open3.capture2('git', '-C', root, *, err: File::NULL)
      output.strip if status.success?
    rescue Errno::ENOENT
      nil
    end

    private_class_method :read_identity, :checkout_commit, :git
  end
end
