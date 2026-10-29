# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Spells out what a literal path names before it is classified.
      module LiteralPaths
        private

        # Shaka's machine allowlist lives under the home directory, which the upgrade does not move.
        def without_machine_paths(text)
          return text unless text.include?('~') || text.match?(/home/i)

          directory = Regexp.escape(PATHS::DIRECTORY)
          name = Regexp.escape(File.basename(PATHS::MACHINE_ALLOWLIST))
          home = /\bhome|Dir\.home|Path\.home\(\)|ENV\[\s*['"]HOME['"]\s*\]|
                  ENV\.fetch\(\s*['"]HOME['"][^)]*\)|['"](?:home|~)['"]/x
          text.gsub(%r{(?:~|\$HOME|\$\{HOME\})/#{directory}/#{name}(?![[:alnum:]_.-])}o, '~/home')
              .gsub(/(?<head>[(,]\s*(?:#{home})\s*,\s*)(?<quote>['"])#{directory}\k<quote>(?=\s*,\s*['"]#{name}['"])/o,
                    '\\k<head>"home"')
        end

        def segmented_reference?(text)
          suffixes = ['bin', 'agent-workflow.yml', 'trusted-github-actors.yml'] +
                     command_paths.map { |path| path.delete_prefix("#{PATHS::DIRECTORY}/") }
          pattern = %r{
            (['"])#{Regexp.escape(PATHS::DIRECTORY)}\1\s*\)?\s*(?:,|/|\+)\s*
            (['"])(?:#{suffixes.map { |suffix| Regexp.escape(suffix) }.join('|')})\2
          }x
          text = without_machine_paths(text)
          text.match?(pattern) || shell_concatenated_reference?(text)
        end

        def shell_concatenated_reference?(text)
          pattern = %r{(['"])#{Regexp.escape(PATHS::DIRECTORY)}\1/+(?:\./)*bin(?:/|#{directory_end})}o
          text.match?(pattern)
        end

        # A join of literal segments names the path they spell, so the old directory joined with `shaka` is the new
        # layout.
        def resolved_joins(text)
          segment = /(['"])([^'"\r\n]*)\1/
          joined = /(['"])#{Regexp.escape(PATHS::DIRECTORY)}\1((?:\s*,\s*#{segment})+)/o
          text.gsub(/^.*\bjoin\s*\(.*$/) do |line|
            line.gsub(joined) do |match|
              segments = ::Regexp.last_match(2).scan(segment).map(&:last)
              # A step back out of a directory is left for the traversal checks.
              segments.intersect?(%w[. ..]) ? match : %("#{[PATHS::DIRECTORY, *segments].join('/')}")
            end
          end
        end
      end
    end
  end
end
