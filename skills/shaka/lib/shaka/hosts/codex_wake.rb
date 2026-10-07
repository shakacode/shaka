# frozen_string_literal: true

require 'json'
require 'time'
require_relative '../error'

module Shaka
  # Checks supplied native registration evidence at the host boundary, never scheduler execution.
  module CodexWake
    THREAD = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
    SCHEDULE = /\A(?:RRULE:)?FREQ=MINUTELY;INTERVAL=[1-9]\d*;UNTIL=(\d{8}T\d{6}Z)\z/
    OTHER_HOSTS = %w[CLAUDE_CODE_SESSION_ID CLAUDE_CODE_HOST_SESSION_ID
                     CURSOR_CONVERSATION_ID OPENCODE_SESSION_ID].freeze

    module_function

    def check(options, repository, number, environment: ENV, now: Time.now)
      path = options[:codex_wake]
      thread = environment['CODEX_THREAD_ID']
      return unless path || (codex_context?(environment) && options[:woken_by])
      raise Error, 'Codex automatic handoff requires --codex-wake PATH; otherwise use manual resume.' unless path

      packet = JSON.parse(File.read(path, encoding: 'UTF-8'))
      target = { 'repository' => repository, 'number' => number.to_i, 'head' => options[:head] }
      validate(packet, thread:, target:, now:)
    rescue JSON::ParserError, SystemCallError => e
      raise Error, "Codex wake evidence unavailable: #{e.class}; use manual resume."
    end

    def codex_context?(environment)
      !environment['CODEX_THREAD_ID'].to_s.empty? && environment['PI_CODING_AGENT'] != 'true' &&
        OTHER_HOSTS.none? { |key| !environment[key].to_s.empty? }
    end

    def validate(packet, thread:, target:, now:)
      raise Error, 'Codex wake evidence must be an object.' unless packet.is_a?(Hash)

      check_target(packet, thread:, target:)
      readback = check_registration(packet, thread:)
      check_expiry(packet, readback, now:)
      readback['id']
    end

    def check_target(packet, thread:, target:)
      valid = thread.to_s.match?(THREAD) && target['head'].to_s.match?(/\A[0-9a-f]{40}\z/) &&
              packet['number'].is_a?(Integer) && packet.slice(*target.keys) == target
      return if valid

      raise Error, 'Codex wake evidence needs the current chat and exact repository, PR number, and --head.'
    end

    def check_registration(packet, thread:)
      native = packet['registration']
      readback = packet['readback']
      expected = { 'id' => native.is_a?(Hash) && native['automationId'], 'kind' => 'heartbeat',
                   'status' => 'ACTIVE', 'target_thread_id' => thread }
      valid = creation_receipt?(native) && readback.is_a?(Hash) && readback.slice(*expected.keys) == expected
      return readback if valid

      raise Error, 'Codex needs successful ACTIVE heartbeat registration and matching same-chat readback.'
    end

    def creation_receipt?(native)
      native.is_a?(Hash) && native['mode'] == 'create' && native['status'] == 'ACTIVE' &&
        native['automationId'].is_a?(String) && !native['automationId'].strip.empty?
    end

    def check_expiry(packet, readback, now:)
      expiry = bounded_expiry(packet, now:)
      schedule_limit = schedule_end(readback)
      return if now < schedule_limit && schedule_limit <= expiry

      raise Error, 'Codex wake schedule limit is expired or exceeds its expiry.'
    end

    def bounded_expiry(packet, now:)
      expiry = timestamp(packet, 'expires_at')
      deadline = timestamp(packet, 'deadline')
      return expiry if now < expiry && expiry <= deadline

      raise Error, 'Codex wake registration is expired or exceeds the task deadline.'
    rescue KeyError, ArgumentError, TypeError
      raise Error, 'Codex wake evidence needs valid expires_at and deadline timestamps.'
    end

    def timestamp(packet, key)
      value = packet.fetch(key)
      raise ArgumentError unless value.is_a?(String) && value.match?(/(?:Z|[+-]\d{2}:\d{2})\z/)

      Time.iso8601(value)
    end

    # An absolute native end avoids inferring a scheduling anchor from creation time.
    def schedule_end(readback)
      schedule = readback['rrule'].to_s.match(SCHEDULE)
      raise Error, 'Codex wake readback needs a finite minute schedule with an absolute UTC UNTIL.' unless schedule

      value = Time.strptime(schedule[1], '%Y%m%dT%H%M%S%z').utc
      raise ArgumentError unless value.strftime('%Y%m%dT%H%M%SZ') == schedule[1]

      value
    rescue ArgumentError
      raise Error, 'Codex wake readback has an invalid UTC UNTIL.'
    end
  end
end
