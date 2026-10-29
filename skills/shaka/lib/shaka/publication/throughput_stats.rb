# frozen_string_literal: true

require 'json'
require_relative '../error'
require_relative 'usage_details'
require_relative 'throughput_line'
require_relative 'throughput_gate'

module Shaka
  # The spend after the model line and the intervals in Timings. Later updates replace only those two.
  class ThroughputStats
    extend ThroughputLine
    extend ThroughputGate

    KEYS = %w[head spend t0 t1 t2 t3].freeze
    TIMES = %w[t0 t1 t2 t3].freeze
    BLOCK = /^<!-- shaka:stats (\{[^\r\n]*\}) -->\r?\n\*\*This head:\*\* [^\r\n]+(?=\r?\n|\z)/
    HEADER = /^(🤖 [^\r\n]*?) - AI spend: [^\r\n]*/
    COST = /^(\*\*Estimated (?:token costs|cost):\*\* [^\r\n·]+?)(?: · (?:ready|merged) in [^\r\n]*)?(?=\r?\n|\z)/

    def self.state(content, timeline = nil, pull = nil) = publish_state(content, timeline || {}, pull)

    def self.update(body, changes)
      original = body.to_s
      state = read(original)
      return original unless state

      state = apply(state, changes)
      replacement = line(state)
      original.sub(BLOCK) { |found| found.include?("\r\n") ? replacement.gsub("\n", "\r\n") : replacement }
              .sub(HEADER) { "#{Regexp.last_match(1)}#{header(state)}" }
              .sub(COST) { "#{Regexp.last_match(1)}#{took(state)}" }
    end

    # A usage refresh must not fail on a damaged block; the next publish rewrites it.
    def self.refresh_spend(body, spend)
      update(body, 'spend' => spend)
    rescue Error
      body
    end

    def self.read(body)
      hits = body.to_s.to_enum(:scan, BLOCK).map { Regexp.last_match(1) }
      return if hits.empty?
      raise Error, 'Description has more than one shaka:stats block.' if hits.size > 1

      parse_block(hits.first)
    end

    class << self
      private

      def parse_block(json)
        data = JSON.parse(json)
        return unless data.is_a?(Hash)
        raise Error, 'Description has an unreadable shaka:stats block.' unless sound?(data)

        data
      rescue JSON::ParserError
        raise Error, 'Description has an unreadable shaka:stats block.'
      end

      def publish_state(content, timeline, pull) = state_for(content, timeline, carried_body(pull), head_sha(pull))

      # Republishing writes a fresh block, so a damaged one must not stop it.
      def carried_body(pull)
        read(pull_body(pull)) || {}
      rescue Error
        {}
      end

      def pull_body(pull) = pull.is_a?(Hash) ? pull['body'] : nil

      def state_for(content, timeline, carried, head)
        base = fresh_state(content, timeline, carried)
        base['head'] = head if head
        same = head && carried['head'] == head
        (same ? carried_state(base, carried) : base).compact
      end

      def fresh_state(content, timeline, carried)
        prompt = prompted_at(timeline)
        { 'spend' => spend(content), 't0' => stamp(timeline['task_started_at']) || carried['t0'],
          't1' => prompt, 't3' => stamp(timeline['merged']) }
      end

      def prompted_at(timeline) = stamp(timeline['ci_started_at'])

      def carried_state(base, carried)
        t1 = base['t1'] ? keep_earlier(base['t1'], carried, 't1', carried['head']) : carried['t1']
        base.merge('t1' => t1, 't2' => carried['t2'], 't3' => base['t3'] || carried['t3'])
      end

      def spend(content)
        usage = content['usage']
        usage.is_a?(Hash) ? UsageDetails.new(usage).detail.fetch('estimate') : 'UNKNOWN'
      end

      def head_sha(pull)
        return unless pull.is_a?(Hash)

        nested = pull['head']
        sha = pull['headRefOid'] || (nested['sha'] if nested.is_a?(Hash))
        sha if sha.is_a?(String) && sha.match?(/\A[0-9a-f]{40}\z/)
      end

      # The body is editable by the pull request author, so a carried value must not close the marker.
      def sound?(data) = data.slice(*KEYS).values.all? { |value| safe_value?(value) } && times?(data)
      def safe_value?(value) = value.nil? || (value.is_a?(String) && one_line?(value))
      def times?(data) = data.slice(*TIMES).values.all? { |value| time_value?(value) }
      def time_value?(value) = [nil, 'UNKNOWN'].include?(value) || plausible_time(value)

      def apply(state, changes)
        merged = state.dup
        changes.each { |key, value| assign(merged, key, value) }
        merged.slice(*KEYS)
      end

      def assign(state, key, value)
        return unless KEYS.include?(key)

        value.nil? ? state.delete(key) : state[key] = checked(key, value)
      end

      def checked(key, value)
        text = value.to_s
        raise Error, "Throughput #{key} must be one line." unless one_line?(text)

        text
      end

      # HTML comments can end with --> or --!>, so either string would close the stats marker early.
      def one_line?(text) = !text.empty? && !text.match?(/[\r\n]/) && comment_safe?(text)
      def comment_safe?(text) = !text.include?('<!--') && !text.include?('-->') && !text.include?('--!>')
    end
  end
end
