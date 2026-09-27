# frozen_string_literal: true

require_relative '../error'
require_relative 'executable'

module Shaka
  # Refuses candidate-controlled PATH entries before any external command runs.
  module LocalReviewPathGuard
    GUARDED_EXECUTABLES = %w[gh git claude codex grok].freeze

    def self.safe_path(path, candidate_root:, drop_candidate: false, inspect_links: true, all_executables: false)
      entries = path.split(File::PATH_SEPARATOR, -1)
      entries.filter_map do |entry|
        normalized_path_entry(entry, candidate_root, drop_candidate, inspect_links, all_executables)
      end
             .join(File::PATH_SEPARATOR)
    end

    def self.normalized_path_entry(entry, candidate_root, drop_candidate, inspect_links, all_executables)
      directory = File.expand_path(entry.empty? ? '.' : entry)
      return directory unless File.directory?(directory)

      state = candidate_path_state(File.realpath(directory), candidate_root, inspect_links, all_executables)
      return if state == :uninspectable
      return directory if state == :safe
      return if drop_candidate

      raise Shaka::Error, 'PATH entry resolves inside candidate checkout'
    end

    def self.candidate_path_state(directory, candidate_root, inspect_links, all_executables)
      return :candidate if LocalReviewExecutable.candidate_owned?(directory, candidate_root)
      return :safe unless inspect_links

      linked = candidate_executable_link?(directory, candidate_root, all_executables)
      return :uninspectable if linked == :uninspectable

      linked ? :candidate : :safe
    end

    def self.candidate_executable_link?(directory, candidate_root, all_executables)
      names = all_executables ? Dir.children(directory) : GUARDED_EXECUTABLES
      names.any? do |name|
        path = File.join(directory, name)
        File.symlink?(path) && File.executable?(path) &&
          LocalReviewExecutable.candidate_owned?(File.realpath(path), candidate_root)
      end
    rescue SystemCallError
      :uninspectable # Omit a PATH directory that cannot be inspected.
    end

    private

    def validate_path!
      ENV['PATH'] = LocalReviewPathGuard.safe_path(ENV.fetch('PATH', ''), candidate_root: root,
                                                                          inspect_links: false)
    end
  end
end
