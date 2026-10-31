# frozen_string_literal: true

require_relative 'usage_test'

class UsageFormatTest < Minitest::Test
  include UsageFixture

  def test_json_format_reports_one_column_per_configuration
    column = json_report.fetch('columns').fetch(0)
    assert_equal 'gpt-test implementation', column.fetch('label')
    assert_equal %w[openai gpt-test high], column.values_at('provider', 'model', 'effort')
    assert_equal %w[100 40 20 5 UNKNOWN],
                 column.values_at('input', 'cached_input', 'output', 'reasoning_output', 'cache_writes')
  end

  def test_json_format_keeps_the_note_and_record
    document = json_report
    assert_equal 'implementation', document.dig('record', 'contribution')
    assert_equal document.fetch('columns'), document.dig('record', 'columns')
    assert_includes document.fetch('note'), 'Native usage is PARTIAL.'
  end

  # Break: a carried report kept its price but lost its rate card and coverage gaps.
  def test_the_record_keeps_its_own_note
    note = json_report.dig('record', 'note')
    assert_includes note, 'Rate card:'
    assert_includes note, 'Native usage is PARTIAL.'
    refute_match(/\d+ responses?\./, note)
    # Break: the JSON note dropped the host caveat the Markdown report prints.
    assert_includes note, 'Cached input is part of input; reasoning output is part of output.'
  end

  def json_report(*flags)
    JSON.parse(run_report([context('current'), usage('current', 'current', 100)], '--format', 'json', *flags))
  end

  # A latest-turn report's first response says nothing about when the task began.
  def test_the_record_says_whether_it_covers_the_whole_task
    refute json_report.dig('record', 'covers_task')
    assert json_report('--all-turns').dig('record', 'covers_task')
    assert json_report('--since-time', '2020-01-01T00:00:00Z').dig('record', 'covers_task')
  end

  def test_json_with_no_responses_uses_unknown_not_zero
    column = JSON.parse(run_report([], '--format', 'json')).fetch('columns').fetch(0)
    assert_equal 'UNKNOWN', column.fetch('input')
    assert_equal 'UNKNOWN', column.fetch('usd')
  end

  def test_markdown_stays_the_default
    report = run_report([context('current'), usage('current', 'current', 100)])
    assert_includes report, '<!-- shaka:usage '
    refute_includes report, '"columns"'
  end

  def test_response_records_keep_model_and_effort_changes_with_exact_counts
    samples = switched_samples
    assert_equal 2, samples.size
    assert_equal %w[100 200], sample_values(samples, 'input')
    assert_equal ['gpt-test high', 'gpt-6.1-sol medium'], sample_routes(samples)
    assert_equal 2, samples.flat_map { |record| record['responses'] }.uniq.size
  end

  def switched_samples
    changed = context('second')
    changed[:payload].merge!(model: 'gpt-6.1-sol', effort: 'medium')
    records = [context('first'), usage('one', 'first', 100), changed, usage('two', 'second', 200)]
    JSON.parse(run_report(records, '--all-turns', '--format', 'json')).fetch('records')
  end

  def sample_routes(samples)
    samples.map { |record| record['columns'][0].values_at('model', 'effort').join(' ') }
  end

  def sample_values(samples, key) = samples.map { |record| record['columns'][0][key] }
end
