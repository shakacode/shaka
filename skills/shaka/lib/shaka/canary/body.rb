# frozen_string_literal: true

require 'open3'
require 'tmpdir'

module Shaka
  module Canary
    # Checks a canary pull-request body for the rendering failures issue 900 names.
    module BodyCheck
      REQUIRED = ['## Summary', '## Intent', '## Verification', '## Shaka metrics'].freeze
      STATS = /AI spend\s+\S+.*·\s*Prompt to CI\s+\S+.*·\s*CI to ready\s+.+·\s*Ready to merged\s+\S+/
      TOKEN = /\{\{[^{}\n]+\}\}/
      LINK = /\[(?:[^\]]*)\]\(([^)\n]*)\)/
      SEPARATOR = /\A:?-+:?\z/

      module_function

      def issues(body)
        text = without_fences(body.to_s)
        [*tokens(text), *sections(text), *stats(text), *tables(text), *links(text)]
      end

      def without_fences(text)
        fence = nil
        text.lines.map do |line|
          shown, fence = visible_line(line, fence)
          shown
        end.join
      end

      def visible_line(line, fence)
        return ["\n", closes_fence?(line, fence) ? nil : fence] if fence

        opening = line.match(/\A {0,3}(`{3,}|~{3,})/)
        opening ? ["\n", opening[1]] : [line, nil]
      end

      def closes_fence?(line, fence) = line.match?(/\A {0,3}#{Regexp.escape(fence[0])}{#{fence.length},}\s*\z/)

      def tokens(text) = text.match?(TOKEN) ? ['unresolved {{token}}'] : []

      def sections(text)
        lines = text.lines.map(&:strip)
        REQUIRED.reject { |heading| lines.include?(heading) }.map { |heading| "missing section #{heading}" }
      end

      def stats(text) = text.match?(STATS) ? [] : ['missing stats line (issue 899)']

      def tables(text) = blocks(text).flat_map { |block| table(block) }

      def blocks(text)
        text.lines.slice_when { |left, right| row?(left) ^ row?(right) }.select { |block| row?(block.first) }
      end

      def row?(line) = line.match?(/\A\s*\|.*\|\s*\z/)

      def table(block)
        counts = block.map { |line| cells(line).size }
        problems = []
        problems << 'table is missing its separator row' if block.none? { |line| separator?(line) }
        problems << 'table rows have different column counts' if counts.uniq.size > 1
        problems
      end

      def cells(line)
        line.gsub(/\\./, 'x').strip.delete_prefix('|').delete_suffix('|').split('|', -1)
      end

      def separator?(line) = cells(line).all? { |cell| cell.strip.match?(SEPARATOR) }

      def links(text)
        text.gsub(/`[^`\n]*`/, '').scan(LINK).filter_map do |dest,|
          'broken link' unless destination_ok?(dest.strip)
        end.uniq
      end

      def destination_ok?(dest)
        url = dest.sub(/\s+(?:"[^"]*"|'[^']*')\z/, '')
        !url.empty? && !url.match?(/\s/)
      end
    end

    # Diffs a canary pull-request body against the previous canary pull request.
    module BodyDiff
      module_function

      def report(previous, current)
        return 'No previous canary PR body.' if previous.to_s.strip.empty?
        return 'Canary PR body matches the previous run.' if previous == current

        unified(previous, current)
      end

      def unified(previous, current)
        Dir.mktmpdir do |dir|
          before = write(dir, 'previous.md', previous)
          after = write(dir, 'current.md', current)
          out, status = Open3.capture2('diff', '-u', '--label', 'previous', '--label', 'current', before, after)
          status.success? ? 'Canary PR body matches the previous run.' : out
        end
      end

      def write(dir, name, text)
        path = File.join(dir, name)
        File.write(path, text)
        path
      end
    end
  end
end
