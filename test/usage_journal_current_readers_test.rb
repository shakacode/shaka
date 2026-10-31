# frozen_string_literal: true

require_relative 'claude_usage_test'
require 'shaka/usage/usage'

class UsageJournalCurrentReadersTest < Minitest::Test
  include ClaudeUsageFixture

  ZERO_SPLIT = { ephemeral_5m_input_tokens: 0, ephemeral_1h_input_tokens: 0 }.freeze

  def test_response_export_keeps_main_and_advisor_models_and_counters_separate
    Dir.mktmpdir do |directory|
      file = transcript(directory, 'session.jsonl', [prompt('turn'), advised_reply])
      records = usage(file).response_records
      assert_advisor_samples(records)
      refute_includes JSON.generate(records), 'SENSITIVE'
    end
  end

  def test_scoped_call_cost_stays_available_without_becoming_a_response_sample
    Dir.mktmpdir do |directory|
      file = print_result_file(directory, shaka_usage_scope: 'independent_call', total_cost_usd: 0.42,
                                          usage: PRINT_USAGE.except(:speed))
      source = usage(file)
      assert_equal '$0.420000', source.json_document.fetch('columns')[0]['usd']
      error = assert_raises(Shaka::Error) { source.response_records }
      assert_includes error.message, 'aggregate'
    end
  end

  def test_a_response_without_a_readable_counter_claims_no_measured_identity
    Dir.mktmpdir do |directory|
      unread = priced_reply('main', 'unreadable')
      unread[:message][:usage] = {}
      file = transcript(directory, 'session.jsonl', [prompt('turn'), unread])
      records = usage(file).response_records
      assert_equal([[]], records.map { |record| record['responses'] })
    end
  end

  private

  def assert_advisor_samples(samples)
    assert_equal %w[100 823], sample_values(samples, 'input')
    assert_equal %w[claude-opus-5 claude-opus-5-5], sample_values(samples, 'routed')
    assert_equal 2, samples.flat_map { |record| record['responses'] }.uniq.size
  end

  def sample_values(samples, key) = samples.map { |record| record['columns'][0][key] }

  def advised_reply
    entry = priced_reply('main', 100)
    executor = { type: 'message', input_tokens: 100, output_tokens: 20,
                 cache_creation_input_tokens: 0 }
    advisor = executor.merge(type: 'advisor_message', model: 'claude-opus-5-5',
                             input_tokens: 823, output_tokens: 1612)
    entry[:message][:usage].merge!(iterations: [executor, advisor], cache_creation_input_tokens: 0,
                                   cache_creation: ZERO_SPLIT)
    entry
  end

  def usage(file)
    Shaka::Usage.new(host: 'claude-code', files: [file], turns: [], all_turns: true,
                     commit: COMMIT, contribution: 'review')
  end
end
