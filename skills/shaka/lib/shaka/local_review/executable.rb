# frozen_string_literal: true

module Shaka
  # Checks whether a documented reviewer executable is reachable on PATH.
  module LocalReviewExecutable
    def self.resolve(name, candidate_root:)
      ENV.fetch('PATH', '').split(File::PATH_SEPARATOR, -1).each do |directory|
        path = File.expand_path(File.join(directory, name))
        next unless File.file?(path) && File.executable?(path)

        target = File.realpath(path)
        if target == candidate_root || target.start_with?("#{candidate_root}/")
          raise Shaka::Error, "#{name} executable resolves inside candidate checkout"
        end

        return target
      end
      nil
    end
  end
end
