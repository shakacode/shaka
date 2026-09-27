# frozen_string_literal: true

module Shaka
  # Checks whether a documented reviewer executable is reachable on PATH.
  module LocalReviewExecutable
    def self.resolve(name, candidate_root:, path: ENV.fetch('PATH', ''))
      path.split(File::PATH_SEPARATOR, -1).each do |directory|
        directory = '.' if directory.empty?
        executable = File.expand_path(File.join(directory, name))
        next unless File.file?(executable) && File.executable?(executable)

        target = File.realpath(executable)
        raise Shaka::Error, "#{name} executable resolves inside candidate checkout" if
          candidate_owned?(target, candidate_root)

        return executable
      end
      nil
    end

    def self.candidate_owned?(target, root) = target == root || target.start_with?("#{root}/")
  end
end
