# frozen_string_literal: true

require_relative '../configuration/feature_guard'
require_relative '../public_comments/bounded_list'

module Shaka
  # GitHub supplies the live PR diff, so publication needs no local copy of its commits.
  module FeaturePublication
    module_function

    def check(github:, pull:, flow:)
      unless Configuration::FeatureGuard::FLOWS.include?(flow)
        raise Error, 'Publication flow must be feature, setup, or migration'
      end
      return unless flow == 'feature'

      files = files(github, pull)
      paths = files.flat_map { |file| [file['filename'], file['previous_filename']].compact }
      return unless paths.any? { |path| Configuration::FeatureGuard.configuration?(path) }

      raise Error, 'Feature PR contains Shaka configuration changes; use a separate setup/migration PR. ' \
                   'Private paths are REDACTED.'
    end

    def files(github, pull)
      files = PublicComments::BoundedList.new(github, max_pages: 30, label: 'PR files')
                                         .call("repos/#{github.repository}/pulls/#{github.number}/files")
      complete!(files, pull)
      files
    end

    def unchanged!(github, existing, original)
      current = github.api("repos/#{github.repository}/pulls/#{github.number}")
      return if current['body'].to_s == existing && current.dig('head', 'sha') == original.dig('head', 'sha') &&
                current.dig('base', 'sha') == original.dig('base', 'sha')

      raise Error, 'The description or PR revision changed while this update was prepared; publish again.'
    end

    def valid_file?(file)
      file['filename'].is_a?(String) && !file['filename'].empty? &&
        (file['previous_filename'].nil? || file['previous_filename'].is_a?(String))
    end

    def complete!(files, pull)
      count = pull['changed_files']
      valid = count.is_a?(Integer) && count.between?(0, 3000) && files.size == count &&
              files.all? { |file| valid_file?(file) }
      raise Error, 'Cannot verify complete PR configuration diff' unless valid
    end
  end
end
