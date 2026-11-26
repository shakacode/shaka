# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative 'usage_snapshot'
require_relative 'usage_report'

module Shaka
  module Evaluation
    # Eval-only adapter for the JSONL sessions collected by the pinned Harbor integrations.
    class NativeUsage
      CARD = 'skills/shaka/config/model-rates.yml'
      attr_reader :rate_card_hash

      def initialize(helper:, rate_root:)
        unless helper.start_with?('/') && File.executable?(helper)
          raise ArgumentError,
                'Expected an absolute installed helper'
        end

        @helper = helper
        @card = File.binread(File.join(rate_root, CARD))
        @rate_card_hash = "sha256:#{Digest::SHA256.hexdigest(@card)}"
      end

      def read(host:, files:, print_result: false)
        raise ArgumentError, 'Expected dedicated native sessions' unless %w[codex claude-code].include?(host) &&
                                                                         files.is_a?(Array) && !files.empty?

        return read_print(files) if host == 'claude-code' && print_result

        capture(host, files)
      end

      private

      def read_print(files)
        Dir.mktmpdir('shaka-eval-usage') do |directory|
          pin_card(directory)
          original = files.fetch(0)
          neutral = File.join(directory, 'neutral.json')
          write_neutral_print(original, neutral)
          reports = [original, neutral].map { |file| report(directory, 'claude-code', [file]) }
          # Print records hash the token counters into the response identity. Both reports
          # come from this one independent call, even though repricing changes its digest.
          UsageReport.normalize(*reports, 'claude-code', expected: 1, same_aggregate: true)
        end
      rescue StandardError
        { 'models' => [], 'cache_neutral_dollars' => 'UNKNOWN', 'billed_dollars' => 'UNKNOWN' }
      end

      def write_neutral_print(original, neutral)
        record = JSON.parse(File.read(original))
        raise ArgumentError unless record['shaka_usage_scope'] == 'independent_call'

        record.delete('total_cost_usd')
        usage = record.fetch('usage')
        UsageSnapshot.claude(usage)
        # The print result has aggregate counters. Its message iterations still
        # carry the original cache-write split, which must not override the new one.
        usage.delete('iterations')
        File.write(neutral, JSON.generate(record), mode: 'wx', perm: 0o600)
      end

      def capture(host, files)
        Dir.mktmpdir('shaka-eval-usage') do |directory|
          pin_card(directory)
          original, neutral, identities = UsageSnapshot.write(directory, host, files)
          UsageReport.normalize(report(directory, host, original), report(directory, host, neutral),
                                host, expected: identities.flatten.uniq.size)
        end
      rescue StandardError
        { 'models' => [], 'cache_neutral_dollars' => 'UNKNOWN', 'billed_dollars' => 'UNKNOWN' }
      end

      def pin_card(directory)
        path = File.join(directory, CARD)
        FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
        File.write(path, @card, mode: 'wx', perm: 0o600)
      end

      def report(directory, host, files)
        arguments = ['usage', '--host', host, '--all-turns', '--format', 'json', '--commit', '0' * 40,
                     '--contribution', 'implementation', '--rate-root', directory]
        output, _errors, status = Open3.capture3(@helper, *arguments, *files.flat_map { |file| ['--file', file] })
        raise IOError, 'Native reader unavailable' unless status.success?

        JSON.parse(output)
      end
    end
  end
end
