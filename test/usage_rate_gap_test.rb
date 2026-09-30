# frozen_string_literal: true

require_relative 'usage_test'

class UsageRateGapTest < Minitest::Test
  include UsageFixture

  def records
    [priced_context('current', 'gpt-99-sol'), priced_usage('response', 'current', 100)]
  end

  def with_failing_github
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, 'gh'), "#!/bin/sh\nprintf called > \"$MARKER\"\nexit 1\n")
      FileUtils.chmod(0o755, File.join(directory, 'gh'))
      marker = File.join(directory, 'called')
      yield({ 'PATH' => "#{directory}:#{ENV.fetch('PATH')}", 'MARKER' => marker }, marker)
    end
  end

  def test_ordinary_reporting_remains_read_only
    with_failing_github do |environment, marker|
      %w[markdown json].each do |format|
        output = run_report(records, '--format', format, environment:)
        assert_includes output, 'UNKNOWN'
        refute_includes output, 'Missing-rate reporting'
        refute_path_exists marker
      end
    end
  end

  def test_opt_in_failure_preserves_both_report_formats
    with_failing_github do |environment, marker|
      %w[markdown json].each do |format|
        output = run_report(records, '--format', format, '--report-missing-rates', environment:)
        assert_includes output, 'failed during repository verification'
        assert_path_exists marker
        FileUtils.rm(marker)
        assert JSON.parse(output).key?('record') if format == 'json'
      end
    end
  end
end
