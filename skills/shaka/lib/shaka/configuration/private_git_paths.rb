# frozen_string_literal: true

require_relative 'paths'

module Shaka
  module Configuration
    # Keep invalid Git path bytes intact while matching valid paths to filesystem strings.
    module PrivateGitPaths
      module_function

      def parse(output)
        output.b.split("\0".b).map do |path|
          native = path.dup.force_encoding(Encoding::UTF_8)
          native.valid_encoding? ? native : path
        end
      end

      def verify_trusted_tree!(sha:, git:)
        paths = parse(git.call('ls-tree', '-r', '-z', '--name-only', sha, Paths::DIRECTORY))
        [Paths::CONTRACT, Paths::NEW_CONTRACT].each do |path|
          git.call('cat-file', '-e', "#{sha}:#{path}") if paths.include?(path)
        end
      end
    end
  end
end
