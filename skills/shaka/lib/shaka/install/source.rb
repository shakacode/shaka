# frozen_string_literal: true

require 'open3'

module Shaka
  module Install
    # Labels copied bytes with an exact Git revision only when every package file matches HEAD.
    class Source
      def initialize(root, names, tree)
        @root = root
        @names = names
        @tree = tree
      end

      def version
        path = File.join(@root, 'skills/shaka/lib/shaka/version.rb')
        match = File.read(path).match(/^\s*VERSION\s*=\s*['"]([^'"]+)['"]/) if File.file?(path)
        match ? match[1] : 'UNKNOWN'
      end

      def identity(hash)
        revision = git('rev-parse', '--verify', 'HEAD') if git('rev-parse', '--show-toplevel') == @root
        exact = revision && tracked? && clean?
        { 'kind' => exact ? 'revision' : 'development', 'repository' => remote,
          'revision' => exact ? revision : nil, 'base_revision' => exact ? nil : revision,
          'content_sha256' => hash }
      end

      private

      def git(*)
        output, status = Open3.capture2('git', '-C', @root, *, err: File::NULL)
        status.success? ? output.strip : nil
      rescue Errno::ENOENT
        nil
      end

      def tracked?
        @names.all? do |name|
          @tree.entries(@root, name).select { |path| File.file?(path) }.all? do |path|
            relative = path.delete_prefix("#{@root}/")
            git('ls-files', '--error-unmatch', '--', relative) == relative
          end
        end
      end

      def clean?
        git('status', '--porcelain', '--untracked-files=all', '--',
            *@names.map { |name| "skills/#{name}" }) == ''
      end

      def remote
        value = git('config', '--get', 'remote.origin.url')
        value if value&.match?(%r{\A(?:https?://|git@)})
      end
    end
  end
end
