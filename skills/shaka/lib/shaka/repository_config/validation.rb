# frozen_string_literal: true

require 'pathname'
require_relative '../error'
require_relative '../trusted_path_resolver'

module Shaka
  class RepositoryConfig
    # Shared primitive validators for repository policy sections.
    module Validation
      private

      def string!(value, label)
        raise Error, "#{label} must be a non-empty string" unless value.is_a?(String) && !value.strip.empty?

        value
      end

      def mapping!(value, label)
        raise Error, "#{label} must be a mapping" unless value.is_a?(Hash) && value.keys.all?(String)

        value
      end

      def keys!(mapping, required, optional, label)
        unknown = mapping.keys - required - optional
        missing = required - mapping.keys
        raise Error, "unknown #{label} key: #{unknown.first}" unless unknown.empty?
        raise Error, "missing #{label} key: #{missing.first}" unless missing.empty?
      end

      def enum!(value, allowed, message)
        raise Error, message unless allowed.include?(value)
      end

      def file!(value, label)
        return committed_file!(value, label) if @sha

        path = repository_path(value, label)
        raise Error, "#{label} does not exist: #{value}" unless File.file?(path)

        real_path = File.realpath(path)
        raise Error, "#{label} must resolve inside the repository" unless real_path.start_with?("#{@root}/")

        path
      end

      def committed_file!(value, label)
        relative = string!(value, label)
        if Pathname.new(relative).absolute? || relative.include?('..')
          raise Error, "#{label} must stay inside the repository"
        end

        _resolved, entry = TrustedPathResolver.new(root: @root, sha: @sha).resolve(relative)
        mode, type = entry || []
        return relative if type == 'blob' && mode != '120000'

        raise Error, "#{label} does not exist at #{@sha}: #{value}"
      end

      def executable!(value, label)
        path = file!(value, label)
        raise Error, "#{label} is not executable: #{value}" unless File.executable?(path)
      end

      def repository_path(value, label)
        relative = string!(value, label)
        expanded = File.expand_path(relative, @root)
        inside = !Pathname.new(relative).absolute? && expanded.start_with?("#{@root}/")
        raise Error, "#{label} must stay inside the repository" unless inside

        expanded
      end
    end
  end
end
