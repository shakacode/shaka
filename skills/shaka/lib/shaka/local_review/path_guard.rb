# frozen_string_literal: true

require_relative '../error'
require_relative 'executable'

module Shaka
  # Refuses candidate-controlled PATH entries before any external command runs.
  module LocalReviewPathGuard
    def self.safe_path(path, candidate_root:)
      entries = path.split(File::PATH_SEPARATOR, -1)
      entries.map { |entry| normalized_path_entry(entry, candidate_root) }.join(File::PATH_SEPARATOR)
    end

    def self.normalized_path_entry(entry, candidate_root)
      directory = File.expand_path(entry.empty? ? '.' : entry)
      if File.directory?(directory)
        target = File.realpath(directory)
        raise Shaka::Error, 'PATH entry resolves inside candidate checkout' if
          LocalReviewExecutable.candidate_owned?(target, candidate_root)
      end
      directory
    end

    private

    def validate_path!
      ENV['PATH'] = LocalReviewPathGuard.safe_path(ENV.fetch('PATH', ''), candidate_root: root)
    end
  end
end
