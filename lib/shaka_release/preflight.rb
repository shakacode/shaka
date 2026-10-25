# frozen_string_literal: true

require 'digest'
require 'json'
require_relative '../../skills/shaka/lib/shaka/evidence/result'
require_relative 'artifact'

module ShakaRelease
  # Maintainer-only checks; a pass identifies inputs for a separate human publication decision.
  class Preflight
    REMOTE = 'https://github.com/shakacode/shaka.git'

    def initialize(root:, commit:, gem:, validation:, notes:)
      @root = root
      @commit = commit
      @gem = gem
      @validation = validation
      @notes = notes
    end

    def check
      check_source
      check_validation
      artifact = Artifact.new(root: @root, path: @gem).check
      version = artifact.fetch('version')
      notes = check_notes(version)
      refuse 'release tag already exists' unless git('ls-remote', '--tags', REMOTE, "refs/tags/v#{version}").empty?
      check_source
      artifact.merge('status' => 'ready_for_approval', 'commit' => @commit,
                     'validation_sha256' => @validation_digest,
                     'notes_sha256' => Digest::SHA256.hexdigest(notes), 'publication_authorized' => false)
    end

    private

    def check_source
      refuse 'commit must be a full SHA matching HEAD' unless @commit.match?(/\A[0-9a-f]{40}\z/) &&
                                                              git('rev-parse', 'HEAD').strip == @commit
      refuse 'requires a clean checkout' unless git('status', '--porcelain', '--untracked-files=all').empty?
      check_index_flags
      remote = git('ls-remote', '--exit-code', REMOTE, 'refs/heads/main').split
      refuse 'commit differs from remote main' unless remote == [@commit, 'refs/heads/main']
    end

    def check_index_flags
      flags = git('ls-files', '-v', '-z').split("\0")
      refuse 'clear hidden index flags before preflight' unless flags.all? { |entry| entry.start_with?('H ') }
    end

    def check_validation
      bytes = File.binread(@validation)
      @validation_digest = Digest::SHA256.hexdigest(bytes)
      result = JSON.parse(bytes)
      bound = Shaka::Evidence::Result.bind(result, root: @root, head: @commit, ref: @commit,
                                                   repository: 'shakacode/shaka')
      refuse 'validation must pass unchanged for this commit and current settings' unless
        bound['status'] == 'bound' && completed_validation?(result)
    rescue SystemCallError, JSON::ParserError, Shaka::Error => e
      refuse "validation: #{e.message}"
    end

    def completed_validation?(result)
      expected = { 'kind' => 'validation', 'command' => 'validate', 'exit_code' => 0, 'inputs_changed' => false }
      expected.all? { |key, value| result[key] == value } && result.dig('task_overrides', 'arguments') == []
    end

    def check_notes(version)
      notes = File.read(@notes)
      changelog = File.read(File.join(@root, 'CHANGELOG.md'))
      section = changelog.split(/^## \[#{Regexp.escape(version)}\][^\n]*\n/, 2)[1]&.split(/^## |^\[[^\]]+\]:/, 2)&.first
      refuse 'notes must match the nonempty version changelog entry' unless section && !notes.strip.empty? &&
                                                                            section.strip == notes.strip
      notes
    end

    def git(*)
      output, error, status = Open3.capture3(Shaka::WorkflowVersion::GIT_ENVIRONMENT, 'git', '-C', @root, *)
      refuse "Git check failed: #{error.strip}" unless status.success?
      output
    end

    def refuse(message) = raise(Shaka::Error, message)
  end
end
