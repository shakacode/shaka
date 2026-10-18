# frozen_string_literal: true

require 'pathname'
require_relative '../doctor/bounded_command'
require_relative '../local_review/path_guard'

module Shaka
  class UpdateCheck
    # Uses the checkout boundary even when startup happens in one of its subdirectories.
    module Launch
      # A command that could not run, with a stable reason for the JSON answer.
      class Unavailable < Shaka::Error
        attr_reader :reason

        def initialize(reason, message)
          @reason = reason
          super(message)
        end
      end

      def self.capture(argv, directory)
        name = argv.first
        root = candidate_root
        path = LocalReviewPathGuard.safe_path(ENV.fetch('PATH', ''), candidate_root: root, drop_candidate: true)
        executable = LocalReviewPathGuard.safe_executable(path, name, root)
        raise Unavailable.new("#{name}_missing", "`#{name}` was not found on PATH.") unless executable

        Doctor::BoundedCommand.new(timeout: 15).call([environment(path), executable, *argv.drop(1)], directory)
      rescue Unavailable
        raise
      rescue Shaka::Error => e
        raise Unavailable.new('unsafe_path', "`#{name}` was not run: #{e.message}.")
      end

      # Outside every repository no candidate checkout can own a PATH entry, so the installed
      # source checkout is the boundary instead.
      def self.candidate_root
        directory = Pathname.new(File.realpath(Dir.pwd))
        outer = directory.ascend.to_a.reverse.find { |parent| parent.join('.git').exist? }
        outer&.to_s || ROOT
      end

      def self.environment(path)
        ENV.keys.grep(/\AGIT_/).to_h { |key| [key, nil] }.merge('PATH' => path, 'BASH_ENV' => nil, 'ENV' => nil)
      end

      private_class_method :candidate_root, :environment
    end
  end
end
