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
    assert_includes document.fetch('note'), 'Native usage is PARTIAL.'
  end

  def json_report
    JSON.parse(run_report([context('current'), usage('current', 'current', 100)], '--format', 'json'))
  end

  def test_markdown_stays_the_default
    report = run_report([context('current'), usage('current', 'current', 100)])
    assert_includes report, '<!-- shaka:usage '
    refute_includes report, '"columns"'
  end
end
