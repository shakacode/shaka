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
        if LocalReviewExecutable.candidate_owned?(target, candidate_root)
          return if drop_candidate

          raise Shaka::Error, 'PATH entry resolves inside candidate checkout'
        end
      end
      directory
    end

    private

    def validate_path!
      ENV['PATH'] = LocalReviewPathGuard.safe_path(ENV.fetch('PATH', ''), candidate_root: root)
    end
  end
end
