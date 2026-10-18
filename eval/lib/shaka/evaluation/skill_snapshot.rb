# frozen_string_literal: true

require 'digest'
require 'json'
require 'open3'

module Shaka
  module Evaluation
    # Self-contained installed trees only; links could load uncaptured external helpers.
    module SkillSnapshot
      module_function

      def read(root)
        root = File.realpath(root)
        rows = tree(root)
        raise ArgumentError unless rows.any? { it.first == 'SKILL.md' }

        identity(root, rows)
      rescue SystemCallError, IOError, ArgumentError
        {}
      end

      def tree(root)
        files = Dir.glob('**/*', File::FNM_DOTMATCH, base: root).sort_by { it.split('/') }
        raise ArgumentError if files.any? { File.symlink?(File.join(root, it)) }

        files.filter_map { row(root, it) }
      end

      def row(root, path)
        file = File.join(root, path)
        return if File.directory?(file)

        raise ArgumentError unless File.file?(file)

        [path, Digest::SHA256.file(file).hexdigest, File.stat(file).mode & 0o111]
      end

      def identity(root, rows)
        { 'source' => root, 'harbor_digest' => harbor_digest(rows),
          'skill_package_digest' => digest(JSON.generate(rows)),
          'skill_commit' => git(root, 'rev-parse', 'HEAD'), 'skill_modified' => modified(root),
          'workflow_hash' => file_digest(root, 'config/workflow.yml'),
          'enforcement_hash' => file_digest(root, 'config/enforcement.yml') }
      end

      # Harbor 0.24.0 skills.py: sorted relative paths, NUL, hex content hash, NUL.
      def harbor_digest(rows) = digest(rows.map { |path, hash, _| "#{path}\0#{hash}\0" }.join)
      def digest(bytes) = "sha256:#{Digest::SHA256.hexdigest(bytes)}"

      def file_digest(root, path)
        file = File.join(root, path)
        File.file?(file) ? "sha256:#{Digest::SHA256.file(file).hexdigest}" : 'UNKNOWN'
      end

      def modified(root)
        status = git(root, 'status', '--porcelain', '--untracked-files=all', '--ignored', '--', '.')
        status == 'UNKNOWN' ? status : !status.empty?
      end

      def git(root, *)
        env = %w[GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE].to_h { [it, nil] }
        output, _, status = Open3.capture3(env, 'git', '-C', root, *)
        status.success? ? output.strip : 'UNKNOWN'
      end
    end
  end
end
