# frozen_string_literal: true

require 'json'
require 'time'

module Shaka
  # Keeps usage reports from earlier hosts, models, and reviews when a description is republished.
  # Each `shaka usage` report is wrapped in hidden markers naming what it counted, so a later agent
  # on any host can tell a refreshed snapshot from a disjoint contribution.
  module UsageRecords
    BEGIN_PREFIX = '<!-- shaka:usage '
    END_MARK = '<!-- shaka:usage:end -->'
    REGION = /<!-- shaka:begin -->(.*?)<!-- shaka:end -->/m
    # A block ends before any later begin marker, so a lost end marker cannot swallow the next report.
    OPENING = Regexp.escape(BEGIN_PREFIX)
    BLOCK = /#{OPENING}([^\n]*) -->\n(?:(?!#{OPENING}).)*?#{Regexp.escape(END_MARK)}/m
    FIELDS = %w[host sources responses contribution commits from to].freeze

    module_function

    def begin_mark(fields) = "#{BEGIN_PREFIX}#{JSON.generate(fields)} -->"

    # Returns the content with carried records prepended to its usage body, and what happened.
    def carry(content, existing)
      stats = { 'retained' => 0, 'replaced' => 0, 'dropped' => 0 }
      usages = usage_details(content)
      usage = usages.first
      region = managed_region(existing)
      kept = usage && region ? carried(region, usages.map { |item| item['body'].to_s }.join("\n\n"), stats) : []
      return [content, stats] if kept.empty?

      [with_usage_body(content, usage, [*kept, usage['body']].join("\n\n")), stats]
    end

    def carried(region, body, stats)
      fresh = text_records(body)
      stats['dropped'] += unterminated(region)
      region.to_enum(:scan, BLOCK).filter_map do
        text = Regexp.last_match[0]
        outcome = outcome(text, parse(Regexp.last_match[1]), fresh, body)
        stats[outcome] += 1 if outcome
        text if outcome == 'retained'
      end
    end

    # A report already pasted into the new body is neither carried nor counted.
    def outcome(text, fields, fresh, body)
      return 'dropped' unless fields && report_shape?(text)
      return if body.include?(text)

      superseded?(fields, fresh) ? 'replaced' : 'retained'
    end

    def unterminated(region) = region.scan(BEGIN_PREFIX).size - region.scan(BLOCK).size

    # A new report must pass the same shape check before it may replace history.
    def text_records(text)
      text.to_enum(:scan, BLOCK).filter_map do
        parse(Regexp.last_match[1]) if report_shape?(Regexp.last_match[0])
      end
    end

    # A carried block must still look like the helper's report, so an edit cannot hide more
    # markers or unbalanced markup under the managed output.
    def report_shape?(text)
      inner = text.sub(/\A.*?\n/, '').delete_suffix(END_MARK)
      !inner.include?('<!-- shaka:') && balanced_details?(inner)
    end

    # Only the helper's own lowercase tags are accepted; any other form could close the outer disclosure.
    def balanced_details?(text)
      tags = text.scan(%r{</?details\b[^>]*>}i)
      return false unless tags.all? { |tag| ['<details>', '</details>'].include?(tag) }

      depth = tags.reduce(0) do |open, tag|
        return false if tag == '</details>' && open.zero?

        tag == '</details>' ? open - 1 : open + 1
      end
      depth.zero?
    end

    def parse(json)
      fields = JSON.parse(json)
      return unless fields.is_a?(Hash) && FIELDS.all? { |key| fields.key?(key) }
      return unless %w[sources responses].all? { |key| fields[key].is_a?(Array) }

      fields
    rescue JSON::ParserError
      nil
    end

    # New reports replace an old one only when they hold every response it counted, so neither a
    # partial overlap nor an empty snapshot of an unreadable source deletes measured usage. An old
    # report without response IDs is replaced by a new one from the same source over an
    # overlapping or unknown interval, since nothing shows them to be different work.
    def superseded?(old, fresh)
      same_host = fresh.select { |new| new['host'] == old['host'] }
      covered?(old, same_host) || same_host.any? { |new| fallback_match?(old, new) }
    end

    def covered?(old, same_host)
      old['responses'].any? && (old['responses'] - same_host.flat_map { |new| new['responses'] }).empty?
    end

    def fallback_match?(old, new)
      return false unless old['responses'].empty?

      old['sources'].intersect?(new['sources']) && intervals_touch?(old, new)
    end

    def intervals_touch?(old, new)
      from, to, new_from, new_to = [old['from'], old['to'], new['from'], new['to']].map { |stamp| time(stamp) }
      return true unless from && to && new_from && new_to

      from <= new_to && new_from <= to
    end

    def time(stamp)
      Time.iso8601(stamp)
    rescue ArgumentError, TypeError
      nil
    end

    def managed_region(existing)
      text = existing.to_s
      return unless text.scan('<!-- shaka:begin -->').size == 1 && text.scan('<!-- shaka:end -->').size == 1

      text[REGION, 1]
    end

    # Carried reports join the first usage section; every usage section holds new reports.
    def usage_details(content)
      details = content.is_a?(Hash) ? content['details'] : nil
      return [] unless details.is_a?(Array)

      details.select { |item| item.is_a?(Hash) && item['summary'].to_s.match?(/usage/i) }
    end

    def with_usage_body(content, usage, body)
      details = content['details'].map { |item| item.equal?(usage) ? usage.merge('body' => body) : item }
      content.merge('details' => details)
    end
  end
end
