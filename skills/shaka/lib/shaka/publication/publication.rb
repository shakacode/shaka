# frozen_string_literal: true

require_relative '../error'
require_relative 'text'
require_relative 'links'
require_relative 'usage_details'
require_relative 'timings_details'
require_relative 'provenance'
require_relative 'provenance_history'
require_relative 'wip_details'
require_relative 'settings'
require_relative 'steps_besides_merging'
require_relative 'human_comments'
require_relative 'skills_used'
require_relative 'metrics'
require_relative 'intent_verification'
require_relative 'quoted_markers'
require_relative '../publication_sections'

module Shaka
  # Renders the publication surfaces so headings, spacing, tables and details are Ruby's.
  class Publication
    include PublicationMetrics

    # With the pull request being replaced, the provenance history carries forward from its body.
    # Callers pass content as a bare hash, so a keyword here would swallow it; every argument is positional.
    def self.description(content, workflow_version = nil, pull = nil, settings = nil, timeline = nil) # rubocop:disable Metrics/ParameterLists
      rendered = new(content, description: true, workflow_version:, pull:, settings:, timeline:)
                 .render(%i[steps intent_verification sections evidence metrics wip credit], lead: %i[lead])
      QuotedMarkers.refuse!(content)
      body, package = DescriptionOverflow.prepare(rendered, pull)
      DescriptionOverflow.remember(pull, package)
      body
    end

    def self.comment(content) = new(content).render([])

    def self.walkthrough(content, repository = nil)
      "#{new(content).render(%i[sections table details], title: true)}\n" \
        "#{PublicationLinks.walkthrough_footer(content['head'], repository)}\n"
    end

    def initialize(content, description: false, workflow_version: nil, pull: nil, settings: nil, timeline: nil) # rubocop:disable Metrics/ParameterLists
      raise Error, 'Publication content must be an object.' unless content.is_a?(Hash)

      @content = content
      @description = description
      @workflow_version = workflow_version
      @pull = pull
      @settings = settings || PublicationSettings.new
      @timeline = timeline
    end

    # A description leads with the maintainer's decision, so lead parts come before the summary.
    # Only a description names its summary, because there the decision line stands above it.
    def render(parts, title: false, lead: [])
      blocks = [PublicationText.publisher_identity(@content)]
      blocks << '# Code Walkthrough' if title
      lead.each { |part| blocks.concat(send(part)) }
      summary = PublicationText.required(@content['summary'], 'summary')
      blocks << (@description ? "## Summary\n\n#{summary}" : summary)
      parts.each { |part| blocks.concat(send(part)) }
      "#{blocks.join("\n\n")}\n"
    end

    private

    # Only a description is rendered with its pull request, so only a description lists what people wrote.
    def sections = PublicationSections.render(@content, HumanComments.for(@content, @pull, @settings))

    def lead = PublicationLinks.lead(@content, @pull, PublicationSections.decisions(@content['decisions']))

    # The steps besides merging sit right under the summary so a reader cannot miss them.
    def steps = StepsBesidesMerging.render(@content)

    def credit = PublicationLinks.credit(@settings)

    # Intent and verification answer whether to trust the merge, so they come before any section.
    def intent_verification
      IntentVerification.render(@content, @settings.verdict, @settings.review_effort_floor, @pull)
    end

    def evidence
      spec = @content.fetch('verification')
      body = [VerificationGates.line(@settings.verdict, @content['review']),
              IntentVerification.evidence(spec, @content['wip'].nil? ? (1..3) : (0..3)), *table, *details]
      [details_block('summary' => 'Evidence and limitations', 'body' => body.join("\n\n"))]
    end

    # Verification carries the proof, so a table only adds facts that fit no check.
    def table
      spec = @content['table']
      return [] if spec.nil?

      columns = table_columns(spec)
      [[table_line(columns), table_line(['---'] * columns.size), *table_data_rows(spec, columns.size)].join("\n")]
    end

    def table_data_rows(spec, width)
      rows = PublicationText.list(spec['rows'], 'table rows')
      raise Error, 'Publication table must include at least one row.' if rows.empty?

      rows.map { |row| table_row(row, width) }
    end

    def table_columns(spec)
      columns = spec.is_a?(Hash) ? PublicationText.list(spec['columns'], 'table columns') : []
      raise Error, 'Publication table must define at least one column.' if columns.empty?

      columns.map { |column| PublicationText.single_line(column, 'table column') }
    end

    def table_row(row, width)
      cells = PublicationText.list(row, 'table row')
      raise Error, "Publication table row has #{cells.size} cells; #{width} columns are defined." if cells.size != width

      table_line(cells.map { |cell| PublicationText.single_line(cell.to_s, 'table cell') })
    end

    def table_line(cells) = "| #{cells.map { |cell| PublicationText.table_cell(cell) }.join(' | ')} |"

    def details
      items = PublicationText.list(@content['details'], 'details')
      validate_details(items) if @description
      items.map { |detail| details_block(detail) }
    end

    def validate_details(items)
      UsageDetails.refuse_free_form!(items)
      refuse_free_form_wip(items)
      refuse_supplied_history(items)
      [PublicationSettings, SkillsUsed, TimingsDetails].each { |validator| validator.refuse_free_form!(items) }
    end

    # The note is optional because it disappears once GitHub confirms the outcome.
    def wip
      spec = @content['wip']
      spec.nil? ? [] : [details_block(WipDetails.new(spec, path_redaction: @settings.path_redaction).detail)]
    end

    def refuse_free_form_wip(items)
      return unless items.any? { |item| item.is_a?(Hash) && item['summary'].to_s.strip.casecmp?(WipDetails::SUMMARY) }

      raise Error, 'Publication WIP Details must be supplied as the wip object, not a details item.'
    end

    # Only the helper writes the history, from the previous body.
    def refuse_supplied_history(items)
      summary = ProvenanceHistory::SUMMARY
      return unless items.any? { |item| item.is_a?(Hash) && item['summary'].to_s.strip.casecmp?(summary) }

      raise Error, 'Publication provenance history is carried from the PR body, not supplied as a details item.'
    end

    def details_block(detail)
      summary = PublicationText.summary_text(detail['summary'], 'details summary')
      body = PublicationText.required(detail['body'], "details #{summary}")
      "<details>\n<summary>#{summary}</summary>\n\n#{body}\n\n</details>"
    end
  end

  # Builds the one comment that holds sections a description can no longer fit, and puts
  # those sections back on the next publish. Included into DescriptionOverflow.
  module OverflowRelocation
    def retire(text, pull)
      stamped = stamp(text, pull, 'comment')
      body = fits?(stamped, pull) ? stamped : text
      [body, { 'comment' => note(text, pull, DescriptionOverflow::RETIRED) }]
    end

    def shed(text, pull)
      body = text
      moved = []
      DescriptionOverflow::KINDS.each do |kind|
        break if fits?(moved.empty? ? body : stamp(body, pull, 'active'), pull)

        piece, body = send(kind, body, pull)
        moved << piece if piece
      end
      [body, moved.compact]
    end

    def pricing(body, pull) = take(body, UsagePricing::SUMMARY, 'Per-report pricing notes', pull)

    def timings(body, pull)
      block, rest = take(body, 'Timings', 'Timings', pull)
      return [nil, body] unless block

      lines = timing_lines(block)
      rest = "#{rest.rstrip}\n\n#{lines.join("\n")}\n" unless lines.empty?
      [block, rest]
    end

    def records(body, pull)
      blocks = usage_blocks(body)
      return [nil, body] if blocks.empty?

      rest = body.gsub(UsageRecords::BLOCK, '').gsub(/\n{3,}/, "\n\n")
      ["#{blocks.join("\n\n")}\n", "#{rest.rstrip}\n\n#{link('Earlier usage reports', pull)}\n"]
    end

    def take(body, summary, label, pull)
      pattern = %r{<details>\n<summary>#{Regexp.escape(summary)}[^<]*</summary>\n.*?\n</details>}m
      block = body[pattern]
      return [nil, body] unless block

      [block, body.sub(block) { link(label, pull) }]
    end

    def comment_text(rendered, moved, pull)
      # The reply marker and its newline are posted ahead of the note.
      budget = DescriptionOverflow::LIMIT - DescriptionOverflow::MARK.length - 1
      full = note(rendered, pull, DescriptionOverflow::INTRO, moved, extra: true)
      return full if full.length <= budget

      # The duplicate usage copy can go; records that were themselves moved stay in `moved`.
      short = note(rendered, pull, DescriptionOverflow::INTRO, moved, extra: false)
      return short if short.length <= budget

      raise Error, DescriptionOverflow::COMMENT_LIMIT
    end

    def note(rendered, pull, intro, moved = [], extra: false)
      parts = [identity(rendered), "# #{title(pull)}", head_line(pull), intro, *moved]
      parts.concat(usage_blocks(rendered)) if extra && !records_moved?(moved)
      "#{parts.compact.join("\n\n")}\n"
    end

    def records_moved?(moved) = moved.any? { |piece| piece.include?('<!-- shaka:usage ') }
    def identity(text) = text.to_s.lines.first.to_s.chomp.then { |line| line if line.start_with?('🤖 ') }

    # scan would return only the fields capture; the comment has to keep the whole record.
    def usage_blocks(text)
      text.to_s.to_enum(:scan, UsageRecords::BLOCK).map { Regexp.last_match(0) }
    end

    def timing_lines(text) = text.to_s.scan(/<!-- (?:timeline-steps|task-timing) .* -->/)

    def stamp(body, pull, tag)
      digest = head_sha(pull)
      return body unless digest

      stripped = body.gsub(/<!-- shaka:overflow-(?:active|comment) [0-9a-f]{40} -->\n?/, '')
      "#{stripped.rstrip}\n\n<!-- shaka:overflow-#{tag} #{digest} -->\n"
    end

    def link(label, pull) = "#{label} are in [#{title(pull)}](#{DescriptionOverflow::PLACEHOLDER})."

    def title(pull)
      return DescriptionOverflow::TITLE unless pull.is_a?(Hash) && pull['number']

      "#{DescriptionOverflow::TITLE} for ##{pull['number']}"
    end

    def head_line(pull) = (digest = head_sha(pull)) && "<!-- shaka:usage-overflow #{digest} -->"

    def head_sha(pull)
      value = pull.is_a?(Hash) && pull.dig('head', 'sha').to_s
      value if value&.match?(/\A[0-9a-f]{40}\z/)
    end

    def post(github, comment)
      posted = github.reply(body: comment, key: DescriptionOverflow::KEY)
      url = posted.is_a?(Hash) ? posted['html_url'] : nil
      return url if url.is_a?(String) && url.start_with?('https://')

      raise Error, 'Usage and timing details comment did not return a URL.'
    end

    def find(github)
      return unless github

      login = github.viewer_login
      Array(github.issue_comments).find { |comment| DescriptionOverflow.ours?(comment, login) }
    end

    def splice(body, comment)
      extra = usage_blocks(comment).reject { |block| body.include?(block) }
      extra.concat(timing_lines(comment).reject { |line| body.include?(line) })
      return body if extra.empty?

      insertion = "#{extra.join("\n\n")}\n\n"
      return body.sub(close_mark, "#{insertion}#{close_mark}") if body.include?(close_mark)

      "#{body.rstrip}\n\n#{insertion}"
    end
  end

  # Joins a rendered description with the prose a person already wrote around the managed region.
  module OverflowMerge
    def merge(existing, body)
      managed = "#{open_mark}\n#{body}#{close_mark}"
      return managed if existing.strip.empty?
      return "#{prefix_of(existing)}#{managed}#{suffix_of(existing)}" if region?(existing)

      "#{managed}\n\n#{existing}"
    end

    def region?(existing)
      existing.scan(open_mark).one? && existing.scan(close_mark).one? &&
        existing.index(open_mark) < existing.index(close_mark)
    end

    def prefix_of(existing) = existing.split(open_mark, 2).first
    def suffix_of(existing) = existing.split(close_mark, 2).last
    def open_mark = marks::OPEN_MARK
    def close_mark = marks::CLOSE_MARK

    def marks
      require_relative 'publishing'
      Publishing
    end
  end

  # When a description would exceed GitHub's body limit, moves the lowest-priority collapsed
  # sections into one comment: per-report pricing notes, then timings, then hidden usage records.
  # The comment is updated in place and keeps the usage markers so the next publish can carry them.
  class DescriptionOverflow
    LIMIT = 65_536
    KEY = 'usage-timing-details'
    TITLE = 'Usage and timing details'
    # Longer than a GitHub comment permalink, so substituting the real URL cannot grow the body.
    PLACEHOLDER = "https://example.com/#{'o' * 160}".freeze
    ACTIVE = /<!-- shaka:overflow-active ([0-9a-f]{40}) -->/
    COMMENT_MARK = /<!-- shaka:overflow-comment ([0-9a-f]{40}) -->/
    HEAD = /<!-- shaka:usage-overflow ([0-9a-f]{40}) -->/
    MARK = "<!-- shaka:reply:#{KEY} -->".freeze
    INTRO = 'These sections were moved out of the PR description so it stays within GitHub\'s 65,536-character limit.'
    RETIRED = 'The description is within GitHub\'s size limit, so these sections are in the description.'
    LIMIT_MESSAGE = "Body exceeds GitHub's 65536-character limit."
    COMMENT_LIMIT = "Usage and timing details comment exceeds GitHub's 65536-character limit."
    KINDS = %i[pricing timings records].freeze

    def self.prepare(rendered, pull)
      return [rendered, nil] if fits?(rendered, pull) && !previous?(pull)

      text = rendered.to_s.gsub("\r\n", "\n")
      return retire(text, pull) if fits?(text, pull)

      relocated(text, pull)
    end

    def self.remember(pull, package)
      pull['shaka_overflow'] = package if package && pull.is_a?(Hash)
    end

    def self.deliver(github, pull, body)
      package = pull.is_a?(Hash) ? pull['shaka_overflow'] : nil
      return body unless package

      url = post(github, package.fetch('comment'))
      return body unless body.include?(PLACEHOLDER)

      body.gsub(PLACEHOLDER, url)
    end

    # Reads markers back from the comment when this description says they were moved.
    def self.restore(github, pull)
      body = pull.is_a?(Hash) ? pull['body'].to_s : ''
      return body unless body.match?(ACTIVE)

      comment = find(github)
      comment ? splice(body, comment['body'].to_s) : body
    end

    def self.issue(description, comment, live)
      described = marker_sha(description)
      commented = comment.to_s[HEAD, 1]
      return 'Publish the usage and timing details comment for this head.' if described && commented.nil?
      return if agree?(described, commented, live)

      'The usage and timing details comment does not match this head; publish the description again.'
    end

    def self.tracked?(description, comment) = marker_sha(description) || comment.to_s[HEAD, 1]

    def self.ours?(comment, login)
      body = comment.is_a?(Hash) ? comment['body'].to_s : ''
      body.start_with?(MARK) && (login.nil? || login.to_s.empty? || comment.dig('user', 'login') == login)
    end

    def self.merged_length(rendered, pull)
      existing = pull.is_a?(Hash) ? pull['body'].to_s : ''
      merge(existing, rendered.to_s).length
    end

    def self.fits?(body, pull) = merged_length(body, pull) <= LIMIT
    def self.previous?(pull) = pull.is_a?(Hash) && pull['body'].to_s.match?(/<!-- shaka:overflow-(?:active|comment) /)
    def self.marker_sha(text) = text.to_s[ACTIVE, 1] || text.to_s[COMMENT_MARK, 1]

    def self.agree?(described, commented, live)
      return true if described.nil? && commented.nil?
      return commented == live if described.nil?
      return described == live if commented.nil?

      described == live && commented == live
    end

    def self.relocated(text, pull)
      body, moved = shed(text, pull)
      raise Error, LIMIT_MESSAGE if moved.empty?

      body = stamp(body, pull, 'active')
      raise Error, LIMIT_MESSAGE unless fits?(body, pull)

      [body, { 'comment' => comment_text(text, moved, pull) }]
    end

    class << self
      include OverflowRelocation
      include OverflowMerge
    end
    private_class_method :fits?, :previous?, :marker_sha, :agree?, :relocated
  end
end
