# frozen_string_literal: true

require 'open3'
require 'uri'

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
        exact = exact_revision?(revision)
        { 'kind' => exact ? 'revision' : 'development', 'repository' => remote,
          'revision' => exact ? revision : nil, 'base_revision' => exact ? nil : revision,
          'content_sha256' => hash }
      end

      private

      def exact_revision?(revision)
        revision && tracked? && clean? && matching_blobs?
      end

      def git(*)
        git_raw(*)&.strip
      end

      def git_raw(*)
        output, status = Open3.capture2('git', '-C', @root, *, err: File::NULL)
        output if status.success?
      rescue Errno::ENOENT
        nil
      end

      def tracked?
        selected = selected_files
        listed = git_raw('ls-files', '-z', '--cached', '--', *selected)
        listed && listed.split("\0").sort == selected.sort
      end

      def selected_files
        paths = @names.flat_map do |name|
          @tree.entries(@root, name).select { |path| File.file?(path) }
        end
        paths.map { |path| path.delete_prefix("#{@root}/") }
      end

      def matching_blobs?
        selected_files.all? do |path|
          git('hash-object', '--path', path, File.join(@root, path)) == git('rev-parse', "HEAD:#{path}")
        end
      end

      def clean?
        git('status', '--porcelain', '--untracked-files=all', '--',
            *@names.map { |name| "skills/#{name}" }) == ''
      end

      def remote
        value = git('config', '--get', 'remote.origin.url')
        return value if value&.match?(/\Agit@[^:]+:.+/)

        web_remote(value)
      end

      def web_remote(value)
        address = URI.parse(value) if value
        return unless address.is_a?(URI::HTTP) && address.host

        address.user = nil
        address.password = nil
        address.query = nil
        address.fragment = nil
        address.to_s
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
