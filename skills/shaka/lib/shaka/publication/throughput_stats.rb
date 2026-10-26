# frozen_string_literal: true

require 'json'
require_relative '../error'
require_relative 'usage_details'
require_relative 'throughput_line'
require_relative 'throughput_gate'

module Shaka
  # The spend and latency line under the model line. Later updates replace only this block.
  class ThroughputStats
    extend ThroughputLine
    extend ThroughputGate

    KEYS = %w[head spend t0 t1 first_push t2 t3 rounds].freeze
    BLOCK = /^<!-- shaka:stats (\{[^\n]*\}) -->\nAI spend [^\n]+$/

    def self.for_description(content, timeline = nil, pull = nil)
      line(publish_state(content, timeline || {}, pull))
    end

    def self.update(body, changes)
      text = body.to_s.gsub("\r\n", "\n")
      state = read(text)
      return text unless state

      text.sub(BLOCK) { line(apply(state, changes)) }
    end

    def self.refresh_spend(body, spend) = update(body, 'spend' => spend)

    def self.read(body)
      hits = body.to_s.gsub("\r\n", "\n").to_enum(:scan, BLOCK).map { Regexp.last_match(1) }
      return if hits.empty?
      raise Error, 'Description has more than one shaka:stats block.' if hits.size > 1

      parse_block(hits.first)
    end

    class << self
      private

      def parse_block(json)
        data = JSON.parse(json)
        data if data.is_a?(Hash)
      rescue JSON::ParserError
        raise Error, 'Description has an unreadable shaka:stats block.'
      end

      def publish_state(content, timeline, pull)
        carried = read(pull_body(pull)) || {}
        state_for(content, timeline, carried, head_sha(pull))
      end

      def pull_body(pull) = pull.is_a?(Hash) ? pull['body'] : nil

      def state_for(content, timeline, carried, head)
        base = fresh_state(content, timeline, carried)
        base['head'] = head if head
        return base.compact unless head && carried['head'] == head

        carried_state(base, carried).compact
      end

      def fresh_state(content, timeline, carried)
        {
          'spend' => spend(content),
          't0' => stamp(timeline['task_started_at']) || carried['t0'],
          't1' => stamp(timeline['head_pushed_at']),
          'first_push' => carried['first_push'] || stamp(timeline['head_pushed_at']),
          't3' => stamp(timeline['merged'])
        }
      end

      def carried_state(base, carried)
        base.merge('t1' => base['t1'] || carried['t1'], 't2' => carried['t2'],
                   't3' => base['t3'] || carried['t3'], 'rounds' => carried['rounds'])
      end

      def spend(content)
        usage = content['usage']
        return 'UNKNOWN' unless usage.is_a?(Hash)

        UsageDetails.new(usage).detail.fetch('estimate')
      end

      def head_sha(pull)
        return unless pull.is_a?(Hash)

        nested = pull['head']
        sha = pull['headRefOid'] || (nested['sha'] if nested.is_a?(Hash))
        sha if sha.is_a?(String) && sha.match?(/\A[0-9a-f]{40}\z/)
      end

      def apply(state, changes)
        merged = state.dup
        changes.each { |key, value| assign(merged, key, value) }
        checked_rounds(merged)
      end

      def checked_rounds(state)
        rounds = state['rounds']
        raise Error, 'CI rounds must be a positive integer.' unless rounds.nil? || positive_round?(rounds)

        state
      end

      def positive_round?(rounds) = rounds.is_a?(Integer) && rounds >= 1

      def assign(state, key, value)
        return unless KEYS.include?(key)

        value.nil? ? state.delete(key) : state[key] = checked(key, value)
      end

      def checked(key, value)
        return value if key == 'rounds'

        text = value.to_s
        raise Error, "Throughput #{key} must be one line." unless one_line?(text)

        text
      end

      def one_line?(text)
        !text.empty? && !text.match?(/[\r\n]/) && comment_safe?(text)
      end

      # HTML comments can end with --> or --!>, so either string would close the stats marker early.
      def comment_safe?(text)
        !text.include?('<!--') && !text.include?('-->') && !text.include?('--!>')
      end
    end
  end
end
