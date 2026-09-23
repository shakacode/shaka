# frozen_string_literal: true

module Shaka
  # Checks whether a documented reviewer executable is reachable on PATH.
  module LocalReviewExecutable
    def self.available?(name)
      ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).any? do |directory|
        path = File.join(directory, name)
        File.file?(path) && File.executable?(path)
      end
    end
  end
end
