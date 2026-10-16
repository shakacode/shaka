# frozen_string_literal: true

require 'pathname'

module Shaka
  # Loads only review criteria present at the separately verified trusted commit.
  module LocalReviewCriteria
    LINK_MODE = '120000'
    FILE_MODES = %w[100644 100755].freeze
    MAX_LINKS = 40

    # Follows symlink entries within one tree; returns the regular file path, or nil when a link
    # is empty, absolute, leaves the repository, dangles, cycles, or ends at a non-file entry.
    def self.resolve(entries, path)
      MAX_LINKS.times do
        mode, object = entries[path]
        return (path if FILE_MODES.include?(mode)) unless mode == LINK_MODE

        path = link_path(path, yield(object))
        return nil unless path
      end
      nil
    end

    def self.link_path(path, target)
      return nil if target.empty? || target.start_with?('/')

      resolved = Pathname.new(File.join(File.dirname(path), target)).cleanpath.to_s
      resolved unless resolved == '..' || resolved.start_with?('../')
    end

    private

    def trusted_criteria(marker)
      ref = @options[:criteria_ref]
      return '' unless ref

      entries = trusted_tree(ref)
      sources = applicable_criteria(entries)
      @criteria_supplied = sources.any? { |_path, source| source }
      sources.map { |path, source| criteria_block(ref, marker, path, source && entries.fetch(source).last) }.join
    end

    def criteria_block(ref, marker, origin, object)
      label = "TRUSTED CRITERIA #{marker}"
      return "--- #{label} NOT SUPPLIED: #{ref}:#{origin} is a link that does not resolve to a file ---\n\n" unless
        object

      text = capture(git_executable, '-C', root, 'cat-file', 'blob', object)
      "--- BEGIN #{label} FROM #{ref}:#{origin} ---\n#{text}\n--- END #{label} ---\n\n"
    end

    # Pairs each applicable AGENTS.md with the regular file it resolves to at the trusted commit, or nil.
    def applicable_criteria(entries)
      paths = capture(git_executable, '-C', root, 'diff', '--no-renames', '--name-only', '-z',
                      "#{@options[:base]}...#{head}", '--').split("\0")
      entries.keys.select { |file| applicable_agents_file?(file, paths) }
             .sort_by { |file| [file.count('/'), file] }
             .map { |file| resolved_criteria(entries, file) }
    end

    def trusted_tree(ref)
      capture(git_executable, '-C', root, 'ls-tree', '-r', '-z', ref, '--').split("\0").to_h do |line|
        metadata, path = line.split("\t", 2)
        mode, _type, object = metadata.split(' ', 3)
        [path, [mode, object]]
      end
    end

    def resolved_criteria(entries, file)
      source = LocalReviewCriteria.resolve(entries, file) do |object|
        capture(git_executable, '-C', root, 'cat-file', 'blob', object)
      end
      [source.nil? || source == file ? file : "#{file} -> #{source}", source]
    end

    def applicable_agents_file?(file, changed_paths)
      return true if file == 'AGENTS.md'
      return false unless file.end_with?('/AGENTS.md')

      directory = File.dirname(file)
      changed_paths.any? { |path| path.start_with?("#{directory}/") }
    end
  end
end
