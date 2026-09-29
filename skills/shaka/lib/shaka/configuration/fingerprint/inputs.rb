# frozen_string_literal: true

require 'find'
require_relative '../../repository_config'
require_relative '../private_inventory'
require_relative 'trusted_prompts'

module Shaka
  module Configuration
    # Selects the inputs actually read from the candidate checkout or trusted commit.
    class FingerprintInputs
      def initialize(root:, settings:, files:, private_source:, trusted_ref:)
        @root = root
        @settings = settings
        @files = files
        @private_source = private_source
        @trusted_ref = trusted_ref
      end

      def hashes
        candidate = candidate_paths
        prompts = prompt_paths
        return @files.hashes(candidate + prompts) if @private_source

        merge_trusted(@files.hashes(candidate), prompts)
      rescue KeyError => e
        raise Error, "Effective settings lack #{e.key}"
      end

      private

      def candidate_paths = private_paths + @settings.fetch('commands').values

      def prompt_paths
        RepositoryConfig.prompt_files(review: @settings.fetch('review'),
                                      opening: @settings.fetch('opening_check')).map(&:last)
      end

      def merge_trusted(candidate, paths)
        trusted = FingerprintTrustedPrompts.new(root: @root, ref: @trusted_ref)
        trusted.hashes(paths.map { |path| @files.safe_path(path) }).each do |path, prompt_digest|
          candidate[path] = combined(candidate[path], prompt_digest)
        end
        candidate.sort.to_h
      end

      def combined(candidate_digest, prompt_digest)
        return prompt_digest unless candidate_digest

        FingerprintCanonical.digest('file-roles', { 'candidate' => candidate_digest, 'trusted' => prompt_digest })
      end

      def private_paths
        return [] unless @private_source

        recorded = @private_source.inventory.map do |entry|
          inventory_path(entry)
        end
        verify_private_inventory!(recorded)
        recorded - [@settings.dig('paths', 'policy_configuration')]
      end

      def verify_private_inventory!(recorded)
        directory = File.join(@root, PrivateInventory::DIRECTORY)
        current = Find.find(directory, ignore_error: false).map { |path| path.delete_prefix("#{@root}/") }
        raise Error, 'Private source changed since preflight; resolve it again' unless current.sort == recorded.sort

        before = FingerprintCanonical.normalize(@private_source.candidate_config.to_h)
        after = FingerprintCanonical.normalize(RepositoryConfig.load(root: @root).to_h)
        raise Error, 'Private settings changed since preflight; resolve them again' unless after == before
      end

      def inventory_path(entry)
        path = entry[:path] if entry.is_a?(Hash)
        raise Error, 'Private source inventory lacks path' unless path.is_a?(String)

        path
      end
    end
  end
end
