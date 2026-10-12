# frozen_string_literal: true

require_relative '../error'
require_relative 'human_comment_rows'
require_relative 'managed_region'

module Shaka
  # Lists what people wrote on a pull request ahead of the agent's own sections, so their comments
  # are not lost among agent posts. Every cell comes from the `shaka comments` result.
  class HumanComments
    # `shaka description --comments PATH` puts that result under this content key.
    KEY = 'human_comments'
    HEADING = 'Human comments'
    OPEN_MARK = '<!-- shaka:human-comments -->'
    CLOSE_MARK = '<!-- /shaka:human-comments -->'
    BLOCK = /#{Regexp.escape(OPEN_MARK)}.*?#{Regexp.escape(CLOSE_MARK)}/m
    HEADER = "| From | Said | Response | Status |\n| --- | --- | --- | --- |"
    SHOWN = 20

    def self.render(content, pull)
      refuse_heading(content['sections'])
      packet = content[KEY]
      return carried(pull) if packet.nil?
      raise Error, 'Human comments need the pull request they were written on.' unless pull

      new(packet, pull).blocks
    end

    # Without a new read the published list stays. A fork author can edit the body, so a
    # fork's list is dropped instead, as its provenance history is.
    def self.carried(pull)
      head = pull&.dig('head', 'repo', 'full_name')
      return [] unless head && head == pull.dig('base', 'repo', 'full_name')

      [Publishing.managed_region(pull['body']).to_s[BLOCK]].compact
    end

    def self.refuse_heading(sections)
      return unless sections.is_a?(Array)
      return unless sections.any? { |item| item.is_a?(Hash) && item['heading'].to_s.strip.casecmp?(HEADING) }

      raise Error, "Publication #{HEADING} is rendered from --comments, not supplied as a section."
    end

    def initialize(packet, pull)
      author = pull.dig('user', 'login')
      check(packet, author, pull.dig('head', 'sha'))
      prefix = "https://github.com/#{pull.dig('base', 'repo', 'full_name')}/pull/#{pull['number']}#"
      @rows = HumanCommentRows.new(HumanCommentEntries.new(packet), author:, prefix:).call
    end

    def blocks
      return [] if @rows.empty?

      lines = @rows.first(SHOWN).map { |row| "| #{row.cells.join(' | ')} |" }
      body = [counts, [HEADER, *lines].join("\n"), *omitted].join("\n\n")
      ["#{OPEN_MARK}\n## #{HEADING}\n\n#{body}\n\n#{CLOSE_MARK}"]
    end

    private

    def check(packet, author, head)
      unless packet.is_a?(Hash)
        raise Error, 'The comments file must hold the object `shaka comments --head SHA` printed.'
      end
      raise Error, 'The pull request author is unavailable for the human comment list.' unless author.is_a?(String)
      return if head && packet['head'] == head

      raise Error, "The comments were read at #{packet['head'] || 'no pull request head'}, but the pull request " \
                   "is at #{head}. Run `shaka comments` for that head and pass its output."
    end

    def counts
      open = @rows.count(&:open)
      "#{open.zero? ? 'None open' : "**#{open} open**"} · #{sources.join(', ')}"
    end

    def sources
      reviewed = @rows.filter_map(&:reviewer)
      unverified = @rows.count(&:unverified)
      authored = @rows.size - reviewed.size - unverified
      people = reviewed.uniq.size
      [("#{reviewed.size} from #{people} reviewer#{'s' if people > 1}" if people.positive?),
       ("#{authored} from the PR author" if authored.positive?),
       ("#{unverified} unverified" if unverified.positive?)].compact
    end

    def omitted
      more = @rows.size - SHOWN
      more.positive? ? ["_#{more} more not shown; open comments come first._"] : []
    end
  end
end
