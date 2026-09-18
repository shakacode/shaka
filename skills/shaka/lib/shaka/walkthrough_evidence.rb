# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Refuses a walkthrough that does not cite live diff and check evidence.
  class WalkthroughEvidence
    def initialize(github)
      @github = github
    end

    def verify(head, body)
      verify_commit_pin(head, body)
      verify_gates(body)
    end

    private

    def verify_commit_pin(head, body)
      files = @github.api_list("repos/#{@github.repository}/pulls/#{@github.number}/files?per_page=100")
      raise Error, 'Walkthrough file list is malformed.' unless files.all?(Hash)

      paths = files.flat_map { |file| [file['filename'], file['previous_filename']].compact }
      return if paths.any? { |path| body.include?(blob_url(head, path)) }

      raise Error, 'Walkthrough requires a commit-pinned link to a changed file.'
    end

    def blob_url(head, path) = "https://github.com/#{@github.repository}/blob/#{head}/#{path}"

    def verify_gates(body)
      missing = gate_names.reject { |name| body.include?(name) }
      return if missing.empty?

      raise Error, "Walkthrough omits completed gates: #{missing.join(', ')}."
    end

    def gate_names
      (completed_names(required_rows) + review_names).uniq
    end

    def required_rows
      @github.checks(required: true)
    rescue Error
      []
    end

    def review_names
      completed_names(@github.checks).grep(/review/i)
    end

    def completed_names(rows)
      rows.filter_map do |row|
        next unless row.is_a?(Hash)

        name = row['name']
        next unless name.is_a?(String) && !name.empty?
        next unless %w[pass fail].include?(row['bucket'].to_s)

        name
      end
    end
  end
end
