# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Tracked reference inventory and checkout overlap checks.
      module References
        private

        def scan_references
          moved = @moves.map { |item| item.fetch('from') }
          tracked_paths.each { |path| scan_reference(path) unless moved.include?(path) }
        end

        def tracked_paths
          output, error, status = Open3.capture3('git', '-C', @root, 'ls-files', '-z')
          raise Error, "Cannot inventory tracked references: #{error.strip}" unless status.success?

          output.split("\0").sort
        end

        def scan_reference(path)
          return scan_symlink_reference(path) if snapshot(path)['type'] == 'symlink'

          text = reference_text(path)
          return unless text

          updated = text.lines.map { |line| rewrite_line(path, line, text.start_with?('#!')) }.join
          return if updated == text

          source = snapshot(path)
          @changes << { from: path, to: path, after: source.merge('data' => [updated.b].pack('m0')) }
        end

        def scan_symlink_reference(path)
          resolved = File.realpath(File.join(@root, path))
          return unless resolved.start_with?("#{@root}/")

          target = resolved.delete_prefix("#{@root}/")
          return unless @moves.any? { |move| move['from'] == target }

          @references << { 'path' => path, 'kind' => 'inbound symlink', 'paths' => [target] }
          @blockers << "#{path}: symlink targets moved #{target}; repair the link explicitly"
        rescue Errno::ENOENT, Errno::ELOOP
          nil
        end

        def reference_text(path)
          return unless snapshot(path)['type'] == 'file'

          text = File.binread(File.join(@root, path)).force_encoding(Encoding::UTF_8)
          text if text.valid_encoding?
        end

        def rewrite_line(path, line, executable)
          keys = matching_paths(line)
          return line if keys.empty? && !command_directory_reference?(line)

          record_reference(path, line, keys)
          return line if historical_line?(path, line)
          return block_directory_reference(path, line) if command_directory_reference?(line)
          return block_reference(path, keys, executable, line) if blocked_reference?(keys, executable, line)

          replace_paths(line, keys)
        end

        def record_reference(path, line, keys)
          paths = command_directory_reference?(line) ? keys + [PATHS::COMMAND_DIRECTORY] : keys
          kind = reference_kind(path, historical_line?(path, line))
          @references << { 'path' => path, 'kind' => kind, 'paths' => paths }
        end

        def replace_paths(line, keys)
          keys.reduce(line) do |result, old|
            result.gsub(token_pattern(old)) { "#{::Regexp.last_match[:lead]}#{reference_mapping.fetch(old)}" }
          end
        end

        def historical_line?(path, line)
          return true if File.basename(path).match?(/\A(?:CHANGELOG|HISTORY|RELEASE[-_]?NOTES)(?:\.|\z)/i)

          path.end_with?('.md') &&
            line.match?(/\A\s*(?:[-*]\s*)?(?:previously|formerly|historically|before upgrade|old path)\b/i)
        end

        def block_directory_reference(path, line)
          @blockers << "#{path}: old command-directory reference needs explicit repair"
          line
        end

        def reference_kind(path, historical)
          return 'historical' if historical
          return 'tracked CI' if path.start_with?('.github/')

          'repository guidance or executable reference'
        end

        def blocked_reference?(keys, executable, line)
          executable || keys.any? { |old| @moves.none? { |move| move['from'] == old } } ||
            keys.any? { |old| dynamic_reference?(line, old) }
        end

        def block_reference(path, keys, executable, line)
          reason = if executable
                     'executable old-path reference'
                   elsif keys.any? { |old| dynamic_reference?(line, old) }
                     "dynamic old-path reference #{keys.join(', ')}"
                   else
                     "reference to unmoved path #{keys.join(', ')}"
                   end
          @blockers << "#{path}: #{reason} needs explicit repair"
          line
        end

        def dirty_overlap
          (git_paths('diff', '--name-only', '-z', 'HEAD', '--') +
            git_paths('ls-files', '--others', '--exclude-standard', '-z')).intersection(entries).each do |path|
            @blockers << "#{path}: overlapping checkout edit; save or repair it before upgrading"
          end
        end

        def git_paths(*)
          output, error, status = Open3.capture3('git', '-C', @root, *)
          raise Error, "Cannot inspect checkout edits: #{error.strip}" unless status.success?

          output.split("\0")
        end
      end
    end
  end
end
