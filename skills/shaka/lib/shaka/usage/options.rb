# frozen_string_literal: true

module Shaka
  # CLI source selection and validation shared by every native usage reader.
  module UsageOptions
    def source_options(flags, options)
      flags.on('--host NAME', Usage::READERS.keys, 'codex, claude-code, cursor, opencode, or pi') do |value|
        options[:host] = value
      end
      source_file_options(flags, options)
      flags.on('--all-turns', 'Only for sources dedicated to this task') { options[:all_turns] = true }
      flags.on('--turn ID', 'Select a native turn; repeat for a shared interval') { |value| options[:turns] << value }
      flags.on('--since-commit SHA', 'Count responses after this commit time in a shared session') do |value|
        options[:since_commit] = value
      end
    end

    def source_file_options(flags, options)
      flags.on('--file PATH', 'Native transcript or export file; repeat for contributors/resumes') do |value|
        options[:files] << value
      end
      flags.on('--session ID', 'OpenCode session; needs --host opencode') do |value|
        options[:files] << "session:#{value}"
      end
    end

    def valid_mapping?(options)
      commits = options[:commit].to_s.split(',')
      options[:host] && valid_selection?(options) && !commits.empty? &&
        commits.all? { |commit| commit.match?(/\A[0-9a-f]{40}\z/) } &&
        %w[implementation review integration shared-planning].include?(options[:contribution])
    end

    def valid_selection?(options)
      return false if options[:all_turns] && options[:turns].any?
      return true unless options[:since_commit]

      !options[:all_turns] && options[:turns].empty? && options[:since_commit].match?(/\A[0-9a-f]{40}\z/)
    end
  end
end
