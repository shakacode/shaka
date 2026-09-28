# frozen_string_literal: true

require_relative 'error'
require_relative 'merge_review_evidence'
require_relative 'publication'
require_relative 'reviewer_selection'

module Shaka
  # Writes the opening of a reply that addresses a review.
  #
  # The author supplies comment URLs. Provider, model, and effort come from that comment's
  # attestation and round ledger, so a reply cannot name a reviewer the comment does not show.
  class ReviewReply
    URL = %r{\Ahttps://github\.com/([\w.-]+)/([\w.-]+)/(pull|issues)/(\d+)#(issuecomment|discussion_r|pullrequestreview)-(\d+)\z}

    def self.compose(content, github) = new(content, github).compose

    def initialize(content, github)
      raise Error, 'Publication content must be an object.' unless content.is_a?(Hash)

      @content = content
      @github = github
    end

    def compose
      lines = lead_lines
      body = Publication.comment(@content)
      return body if lines.empty?

      "#{lines.join("\n")}\n\n#{body}"
    end

    private

    def lead_lines
      urls = @content['reviews']
      return [] if urls.nil?
      raise Error, 'A review reply needs each comment URL it addresses.' unless urls.is_a?(Array) && !urls.empty?

      urls.map { |url| line(url) }
    end

    def line(url)
      raise Error, 'A review reply takes a comment URL, not a typed reviewer identity.' unless url.is_a?(String)

      Evidence.line(body: located(url).fetch('body').to_s, url: url)
    end

    def located(url)
      match = url.match(URL)
      raise Error, 'A review comment URL must point at a comment on this pull request.' unless on_pull?(match)

      found = comments(match[5], match[6]).find { |comment| comment.is_a?(Hash) && comment['id'].to_s == match[6] }
      return found if found

      raise Error, 'The review comment was not found on this pull request.'
    end

    def on_pull?(match)
      return false unless match

      owner, repo, path, number, fragment, = match.captures
      return false unless "#{owner}/#{repo}".casecmp?(@github.repository) && number.to_i == @github.number
      return true if path == 'pull'

      path == 'issues' && fragment == 'issuecomment'
    end

    def comments(fragment, id)
      case fragment
      when 'issuecomment' then @github.issue_comments
      when 'discussion_r'
        @github.api_list("repos/#{@github.repository}/pulls/#{@github.number}/comments")
      else
        [@github.review(id)]
      end
    end

    # One published review comment, read back into the opening line.
    class Evidence
      HEADING = /^# ([^\[\]\r\n]+)$/
      COLUMNS = %w[Commit Reviewer Model].freeze

      def self.line(body:, url:) = new(body, url).line

      def initialize(body, url)
        @body = body
        @url = url
      end

      def line
        provider, model, effort, sha = identity
        short = sha ? sha[0, 7] : 'UNKNOWN'
        "Addressed the [#{heading}](#{@url}) by #{provider}/#{model} (#{effort}) on `#{short}`."
      end

      private

      def heading
        text = @body.each_line.map(&:rstrip).find { |row| row.match?(HEADING) }&.delete_prefix('# ')
        text.nil? || text.strip.empty? ? 'review' : text.strip
      end

      def identity
        sha, reviewer, effort, = @body.match(MergeReviewEvidence::ATTESTATION)&.captures
        parsed = parse_reviewer(reviewer)
        return %w[UNKNOWN UNKNOWN UNKNOWN] unless parsed

        [parsed.fetch('provider'), ledger_model(sha, reviewer), effort, sha]
      end

      def parse_reviewer(reviewer)
        return unless reviewer

        ReviewerSelection.parse(reviewer)
      rescue Error
        nil
      end

      def ledger_model(sha, reviewer)
        row = ledger_rows.reverse.find { |cells| match_row?(cells, sha, reviewer) }
        model = row && row[:model]
        model.nil? || model.empty? ? 'UNKNOWN' : model
      end

      def match_row?(cells, sha, reviewer)
        cells[:commit].include?(sha[0, 7]) && cells[:reviewer].casecmp?(reviewer)
      end

      def ledger_rows
        rows = table_rows
        header = rows.find { |cells| (COLUMNS - cells).empty? }
        return [] unless header

        indexes = COLUMNS.to_h { |name| [name, header.index(name)] }
        rows.drop(rows.index(header) + 1).filter_map { |cells| record(cells, indexes) }
      end

      def record(cells, indexes)
        return if cells.all? { |cell| cell.match?(/\A:?-+:?\z/) }
        return if indexes.each_value.any? { |index| cells[index].nil? }

        { commit: unescape(cells[indexes['Commit']]), reviewer: unescape(cells[indexes['Reviewer']]),
          model: unescape(cells[indexes['Model']]) }
      end

      def table_rows
        @body.each_line.filter_map { |row| split_cells(row.rstrip) }
      end

      def split_cells(row)
        return unless row.start_with?('|') && row.end_with?('|')

        cells = []
        current = +''
        escaped = false
        row[1..].chomp('|').each_char do |char|
          escaped, current = next_cell(char, escaped, current, cells)
        end
        cells << current.strip
      end

      def next_cell(char, escaped, current, cells)
        return [false, current << "\\#{char}"] if escaped
        return [true, current] if char == '\\'

        cells << current.strip if char == '|'
        current = +'' if char == '|'
        [false, char == '|' ? current : current << char]
      end

      def unescape(cell) = cell.gsub(/\\([\\|])/, '\1').strip
    end
  end
end
