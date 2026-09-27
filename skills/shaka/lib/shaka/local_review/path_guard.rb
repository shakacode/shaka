# frozen_string_literal: true

require_relative '../error'
require_relative 'executable'

module Shaka
  # Refuses candidate-controlled PATH entries before any external command runs.
  module LocalReviewPathGuard
    def self.safe_path(path, candidate_root:, drop_candidate: false)
      entries = path.split(File::PATH_SEPARATOR, -1)
      entries.filter_map { |entry| normalized_path_entry(entry, candidate_root, drop_candidate) }
             .join(File::PATH_SEPARATOR)
    end

    def self.normalized_path_entry(entry, candidate_root, drop_candidate)
      directory = File.expand_path(entry.empty? ? '.' : entry)
      return directory unless File.directory?(directory)

      state = candidate_path_state(File.realpath(directory), candidate_root)
      return if state == :uninspectable
      return directory if state == :safe
      return if drop_candidate

      raise Shaka::Error, 'PATH entry resolves inside candidate checkout'
    end

    def self.candidate_path_state(directory, candidate_root)
      return :candidate if LocalReviewExecutable.candidate_owned?(directory, candidate_root)

      linked = candidate_executable_link?(directory, candidate_root)
      return :uninspectable if linked == :uninspectable

      linked ? :candidate : :safe
    end

    def self.candidate_executable_link?(directory, candidate_root)
      Dir.children(directory).any? do |name|
        path = File.join(directory, name)
        File.symlink?(path) && File.executable?(path) &&
          LocalReviewExecutable.candidate_owned?(File.realpath(path), candidate_root)
      end
    rescue SystemCallError
      :uninspectable # Omit a PATH directory that cannot be inspected.
    end

    private

    def validate_path!
      ENV['PATH'] = LocalReviewPathGuard.safe_path(ENV.fetch('PATH', ''), candidate_root: root)
    end
  end
end
