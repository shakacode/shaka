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
          return line if keys.empty?

          historical = historical_line?(path, line)
          @references << { 'path' => path, 'kind' => reference_kind(path, historical), 'paths' => keys }
          return line if historical
          return block_reference(path, keys, executable, line) if blocked_reference?(keys, executable, line)

          keys.reduce(line) do |result, old|
            result.gsub(token_pattern(old)) { "#{::Regexp.last_match[:lead]}#{reference_mapping.fetch(old)}" }
          end
        end

        def historical_line?(path, line)
          return true if File.basename(path).match?(/\A(?:CHANGELOG|HISTORY|RELEASE[-_]?NOTES)(?:\.|\z)/i)

          path.end_with?('.md') && line.match?(/\b(previously|formerly|historically|before upgrade|old path)\b/i)
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

        def matching_paths(text)
          reference_mapping.keys.select { |old| text.match?(token_pattern(old)) || dynamic_reference?(text, old) }
        end

        def dynamic_reference?(text, old)
          escaped = Regexp.escape(old)
          variable = %r~(?:\$\{\{[^}]+\}\}|\$\{[^}]+\}|#\{[^}]+\})/#{escaped}(?![[:alnum:]_./-])~
          absolute = %r{(?:\A|[\s"'=])/(?:[^/\s"']+/)*#{escaped}(?![[:alnum:]_./-])}
          text.match?(variable) || text.match?(absolute)
        end

        def token_pattern(path)
          leading = '(?<![[:alnum:]_./-])(?<lead>\./|\$[A-Za-z_]\w*/|"\$[A-Za-z_]\w*"/)?'
          Regexp.new("#{leading}#{Regexp.escape(path)}(?![[:alnum:]_./-])")
        end

        def reference_mapping
          { PATHS::CONTRACT => PATHS::NEW_CONTRACT,
            PATHS::REPOSITORY_ALLOWLIST => PATHS::NEW_REPOSITORY_ALLOWLIST }.merge(
              command_paths.to_h { |old| [old, old.sub(PATHS::COMMAND_DIRECTORY, PATHS::NEW_COMMAND_DIRECTORY)] }
            )
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
