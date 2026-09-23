# frozen_string_literal: true

module Shaka
  # Checks whether a documented reviewer executable is reachable on PATH.
  module LocalReviewExecutable
    def self.resolve(name, candidate_root:)
      ENV.fetch('PATH', '').split(File::PATH_SEPARATOR, -1).each do |directory|
        directory = '.' if directory.empty?
        path = File.expand_path(File.join(directory, name))
        next unless File.file?(path) && File.executable?(path)

        target = File.realpath(path)
        raise Shaka::Error, "#{name} executable resolves inside candidate checkout" if
          candidate_owned?(target, candidate_root)

        return path
      end
      nil
    end

    def self.candidate_owned?(target, root) = target == root || target.start_with?("#{root}/")
  end
end
