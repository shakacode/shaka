# frozen_string_literal: true

module Shaka
  # Checks whether a documented reviewer executable is reachable on PATH.
  module LocalReviewExecutable
    def self.resolve(name)
      ENV.fetch('PATH', '').split(File::PATH_SEPARATOR, -1).each do |directory|
        path = File.expand_path(File.join(directory, name))
        return path if File.file?(path) && File.executable?(path)
      end
      nil
    end
  end
end
