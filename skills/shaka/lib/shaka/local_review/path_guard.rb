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
      if File.directory?(directory)
        target = File.realpath(directory)
        if candidate_path?(target, candidate_root)
          return if drop_candidate

          raise Shaka::Error, 'PATH entry resolves inside candidate checkout'
        end
      end
      directory
    end

    def self.candidate_path?(directory, candidate_root)
      LocalReviewExecutable.candidate_owned?(directory, candidate_root) ||
        candidate_executable_link?(directory, candidate_root)
    end

    def self.candidate_executable_link?(directory, candidate_root)
      Dir.children(directory).any? do |name|
        path = File.join(directory, name)
        File.symlink?(path) && File.executable?(path) &&
          LocalReviewExecutable.candidate_owned?(File.realpath(path), candidate_root)
      end
    rescue SystemCallError
      true # A PATH directory that cannot be inspected cannot be trusted.
    end

    private

    def validate_path!
      ENV['PATH'] = LocalReviewPathGuard.safe_path(ENV.fetch('PATH', ''), candidate_root: root)
    end
  end
end
