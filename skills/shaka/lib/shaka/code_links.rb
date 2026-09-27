# frozen_string_literal: true

require 'uri'
require_relative 'code_link_range'

module Shaka
  # Turns walkthrough `code:NAME` link targets into commit-pinned line-range permalinks.
  # Each name locates its lines by text in the file at the head, so a range cannot drift
  # onto other code when earlier commits move lines, and text that is missing or matches
  # more than one line refuses publication instead of guessing.
  class CodeLinks
    REFERENCE = /\]\(code:([A-Za-z0-9_.-]+)\)/
    # Fenced blocks and inline code spans show Markdown literally, so links there stay as written.
    CODE = /(^[ \t]*```.*?^[ \t]*```[^\n]*$|`[^`\n]*`)/m

    # Rewrites the rendered walkthrough, so links in the summary, sections, table, and
    # details all resolve the same way.
    def self.resolve(body, content, github)
      return body unless content.key?('code_links')

      new(content.fetch('code_links'), github, content.fetch('head')).rewrite(body)
    end

    def initialize(links, github, head)
      raise Error, 'Walkthrough code_links must be an object.' unless links.is_a?(Hash)

      @links = links
      @github = github
      @head = head
      @files = {}
      @urls = {}
    end

    def rewrite(body)
      body.split(CODE).each_with_index.map do |part, index|
        index.odd? ? part : part.gsub(REFERENCE) { "](#{url(Regexp.last_match(1))})" }
      end.join
    end

    private

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
      CodeLinkRange.find(file(name, path), from, to: link['to'], block: link['block'])
    rescue Error => e
      raise e if e.message.start_with?('Walkthrough code link')

      raise Error, "Walkthrough code link #{name}: #{e.message}"
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
