# frozen_string_literal: true

require 'uri'
require_relative 'error'

module Shaka
  # Turns walkthrough `code:NAME` link targets into commit-pinned line-range permalinks.
  # Each name locates its lines by text in the file at the head, so a range cannot drift
  # onto other code when earlier commits move lines, and text that is missing or matches
  # more than one line refuses publication instead of guessing.
  class CodeLinks
    REFERENCE = /\]\(code:([A-Za-z0-9_.-]+)\)/
    CLOSER = /\A(?:end\b|[}\])])/

    def self.resolve(content, github)
      return content unless content.key?('code_links')

      new(content.fetch('code_links'), github, content.fetch('head')).apply(content)
    end

    def initialize(links, github, head)
      raise Error, 'Walkthrough code_links must be an object.' unless links.is_a?(Hash)

      @links = links
      @github = github
      @head = head
      @files = {}
      @urls = {}
    end

    def apply(content)
      resolved = content.except('code_links')
      resolved['summary'] = rewrite(content['summary']) if content['summary'].is_a?(String)
      %w[sections details].each do |key|
        next unless content[key].is_a?(Array)

        resolved[key] = content[key].map { |item| item.is_a?(Hash) ? rewrite_body(item) : item }
      end
      resolved
    end

    private

    def rewrite_body(item)
      item['body'].is_a?(String) ? item.merge('body' => rewrite(item['body'])) : item
    end

    def rewrite(text)
      text.gsub(REFERENCE) { "](#{url(Regexp.last_match(1))})" }
    end

    def url(name)
      @urls[name] ||= begin
        link = @links[name]
        raise Error, "Walkthrough references undefined code link #{name}." unless link

        first, last = range(name, link)
        anchor = first == last ? "#L#{first}" : "#L#{first}-L#{last}"
        "https://github.com/#{@github.repository}/blob/#{@head}/#{encoded(link['path'])}#{anchor}"
      end
    end

    def range(name, link)
      path, from = definition(name, link)
      lines = file(name, path)
      start = unique_line(name, lines, from)
      finish = if link['block'] then block_end(lines, start)
               elsif link['to'] then later_line(name, lines, start, link['to'])
               else start
               end
      [start + 1, finish + 1]
    end

    def definition(name, link)
      raise Error, "Walkthrough code link #{name} must be an object." unless link.is_a?(Hash)
      raise Error, "Walkthrough code link #{name} needs a repository-relative path." unless relative?(link['path'])
      raise Error, "Walkthrough code link #{name} needs from text." unless text?(link['from'])

      check_end(name, link)
      [link['path'], link['from']]
    end

    def check_end(name, link)
      raise Error, "Walkthrough code link #{name} takes either to or block, not both." if link['block'] && link['to']
      raise Error, "Walkthrough code link #{name} has invalid to text." if link.key?('to') && !text?(link['to'])
    end

    def relative?(path)
      path.is_a?(String) && !path.start_with?('/') && !path.split('/', -1).intersect?(['', '.', '..'])
    end

    def text?(value) = value.is_a?(String) && !value.strip.empty?

    def unique_line(name, lines, text)
      matches = lines.each_index.select { |index| lines[index].include?(text) }
      return matches.first if matches.size == 1

      raise Error, "Walkthrough code link #{name}: #{text.inspect} matches #{matches.size} lines; use unique text."
    end

    def later_line(name, lines, start, text)
      found = (start...lines.size).find { |index| lines[index].include?(text) }
      return found if found

      raise Error, "Walkthrough code link #{name}: no line at or after #{lines[start].strip.inspect} " \
                   "contains #{text.inspect}."
    end

    # The block ends at the next line indented no deeper than its first line. A closing
    # `end`, brace, or bracket belongs to the block; any other line starts the next one.
    def block_end(lines, start)
      depth = indentation(lines[start])
      last = start
      lines[(start + 1)..].each_with_index do |line, offset|
        next if line.strip.empty?
        return (line.strip.match?(CLOSER) ? start + 1 + offset : last) if indentation(line) <= depth

        last = start + 1 + offset
      end
      last
    end

    def indentation(line) = line[/\A[ \t]*/].size

    def file(name, path)
      @files[path] ||= begin
        response = @github.api("repos/#{@github.repository}/contents/#{encoded(path)}?ref=#{@head}")
        unless response['type'] == 'file' && response['encoding'] == 'base64'
          raise Error, "#{path} is not a regular file under 1 MB at #{@head}."
        end

        response['content'].to_s.unpack1('m').force_encoding(Encoding::UTF_8).split("\n", -1)
      end
    rescue Error => e
      raise Error, "Walkthrough code link #{name}: #{e.message}"
    end

    def encoded(path) = path.split('/').map { |segment| URI.encode_uri_component(segment) }.join('/')
  end
end
