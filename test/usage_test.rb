# frozen_string_literal: true

require_relative 'test_helper'
require 'json'

module UsageFixture
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  COMMIT = 'a' * 40
  THREAD = '00000000-0000-0000-0000-000000000001'
  NATIVE_OPENAI = <<~TABLE.chomp
    | Metric | openai |
    | --- | --- |
    | Provider | openai |
    | Configured model | gpt-test |
    | Routed model | UNKNOWN |
    | Effort | high |
    | Input | 100 |
    | Cached input | 40 |
    | Output | 20 |
    | Reasoning output | 5 |
    | Cache writes | UNKNOWN |
    | Native total | UNKNOWN |
  TABLE

  private

  def context(turn)
    { type: 'turn_context', payload: { turn_id: turn, model: 'gpt-test', effort: 'high' } }
  end

  def usage(response, turn, input)
    { type: 'token_usage_record', timestamp: '2026-09-14T12:00:00Z',
      payload: { response_id: response, turn_id: turn,
                 usage: { input_tokens: input, cached_input_tokens: 40,
                          output_tokens: 20, reasoning_output_tokens: 5 },
                 thread_token_usage: { input_tokens: 9999 } } }
  end

  def run_report(records, *, **options)
    Dir.mktmpdir do |directory|
      file = write_records(directory, records, options)
      environment = host_environment(directory).merge(options.fetch(:environment, {}))
      sources = options[:discover] ? [] : ['--file', file] * options.fetch(:copies, 1)
      output, error, status = Open3.capture3(environment, COMMAND, 'usage', *sources,
                                             '--commit', COMMIT, '--contribution', 'implementation', *)
      assert_predicate status, :success?, error
      output
    end
  end

  def host_environment(directory)
    { 'PI_CODING_AGENT' => nil, 'CODEX_HOME' => directory, 'CODEX_THREAD_ID' => THREAD,
      'CLAUDE_CODE_SESSION_ID' => nil, 'CURSOR_CONVERSATION_ID' => nil }
  end

  def write_records(directory, records, options)
    folder = File.join(directory, 'sessions', '2026', '09', '14')
    FileUtils.mkdir_p(folder)
    file = File.join(folder, "rollout-#{THREAD}.jsonl")
    metadata = { type: 'session_meta', payload: { id: options.fetch(:identity, THREAD), model_provider: 'openai',
                                                  cli_version: '0.154.0-alpha.6.2' } }
    metadata = options.fetch(:metadata, metadata)
    File.write(file, "#{[metadata, *records].map { |record| JSON.generate(record) }.join("\n")}\n")
    File.write(file, options.fetch(:raw_tail, ''), mode: 'a')
    file
  end

  def priced_context(turn, model, effort: 'high')
    context(turn).tap { |setting| setting[:payload].merge!(model: model, effort: effort) }
  end

  def priced_usage(id, turn, input, **tokens)
    usage(id, turn, input).tap do |response|
      response[:payload][:usage].merge!(cached_input_tokens: tokens.fetch(:cached, 0),
                                        cache_write_input_tokens: tokens.fetch(:writes, 0),
                                        output_tokens: tokens.fetch(:output, 20), reasoning_output_tokens: 0)
    end
  end
end

class UsageTest < Minitest::Test
  include UsageFixture

  def test_native_usage_table_uses_metric_rows_instead_of_a_wide_provider_row
    report = run_report([context('current'), usage('current', 'current', 100)])
    native = report[%r{<details>.*?</details>}m]
    refute_includes native, '| Provider | Configured model | Routed model | Effort | Input |'
    assert_includes native, NATIVE_OPENAI
  end

  def test_counts_each_response_once_in_latest_turn_without_adding_cumulative_snapshots
    records = [context('old'), usage('old-response', 'old', 900), context('current'),
               usage('response-1', 'current', 100), usage('response-1', 'current', 100),
               usage('response-2', 'current', 200),
               { type: 'event_msg', payload: { type: 'token_count', info: { total_tokens: 9999 } } }]
    report = run_report(records)
    assert_metric report, 'Input', 300
    assert_includes report, 'gpt-test'
    assert_includes report, 'high'
    assert_includes report, '2 responses'
    refute_includes report, '9999'
  end

  def test_explicit_turns_across_resumed_files_are_shared_without_recounting_responses
    records = [context('old'), usage('first', 'old', 900), context('current'), usage('second', 'current', 100)]
    report = run_report(records, '--turn', 'old', '--turn', 'current',
                        '--commit', "#{COMMIT},#{'b' * 40}", copies: 2)
    assert_metric report, 'Input', 1000
    assert_includes report, 'SHARED'
    assert_includes report, '2 responses'
    assert_includes report, '2026-09-14T12:00:00Z'
    assert_includes report, 'PARTIAL'
    assert_includes report, 'External reviewer/tool-model usage: UNKNOWN'
  end

  def test_missing_fields_stay_unknown_and_each_turn_keeps_its_configured_model
    incomplete = usage('first', 'old', 100)
    incomplete[:payload][:usage].delete(:cached_input_tokens)
    changed = context('current')
    changed[:payload].merge!(model: 'gpt-other', effort: 'low')
    records = [context('old'), incomplete, changed, usage('second', 'current', 200)]
    report = run_report(records, '--turn', 'old', '--turn', 'current')
    assert_metric report, 'Configured model', 'gpt-test', 'gpt-other'
    assert_metric report, 'Input', 100, 200
    assert_metric report, 'Cached input', 'UNKNOWN', 40
    assert_includes report, '0.154.0-alpha.6.2'
  end

  def test_preserves_native_cache_writes_and_total_without_adding_subsets
    response = usage('current', 'current', 100)
    response[:payload][:usage].merge!(cache_write_input_tokens: 7, total_tokens: 120)
    report = run_report([context('current'), response])
    assert_metric report, 'Input', 100
    assert_metric report, 'Cache writes', 7
    assert_metric report, 'Native total', 120
    assert_includes report, 'Native total'
  end

  def test_unidentifiable_or_truncated_records_cannot_inflate_usage_or_leak_private_content
    unidentifiable = usage('unknown', 'current', 9900)
    unidentifiable[:payload].delete(:response_id)
    report = run_report([context('current'), usage('counted', 'current', 100), unidentifiable],
                        raw_tail: '{"private-prompt": "SENSITIVE-INCOMPLETE')
    assert_metric report, 'Input', 100
    assert_metric report, 'Cached input', 40
    assert_includes report, 'Unreadable or unidentifiable records'
    refute_includes report, 'SENSITIVE'
    refute_includes report, '9900'
  end

  def test_all_turns_counts_a_dedicated_task_once_and_discloses_scope
    records = [context('old'), usage('old', 'old', 900), context('current'), usage('current', 'current', 100)]
    report = run_report(records, '--all-turns', copies: 2)
    assert_metric report, 'Input', 1000
    assert_includes report.split('<details>').first, 'all turns'
    refute_includes report, 'old-response'
  end

  def test_default_visibly_discloses_that_earlier_turns_are_excluded
    report = run_report([context('old'), usage('old', 'old', 900),
                         context('current'), usage('current', 'current', 100)], discover: true)
    assert_includes report.split('<details>').first, 'latest turn only'
  end

  def test_discovers_current_thread_from_host_context_and_uses_only_latest_turn
    report = run_report([context('old'), usage('old', 'old', 900),
                         context('current'), usage('current', 'current', 100)], discover: true)
    assert_metric report, 'Input', 100
    assert_includes report, 'host context'
    assert_includes report, 'SHARED'
    refute_includes report, THREAD
  end

  # Break caught: an unreadable replacement context left the earlier model in place,
  # so later responses were priced at a rate the session may no longer have used.
  def test_unreadable_line_does_not_leave_earlier_settings_on_later_responses
    replacement = %({"type":"turn_context","payload":{"turn_id":"current","model":"gpt-\xFF"}}\n).b +
                  "#{JSON.generate(usage('current', 'current', 50))}\n"
    report = run_report([context('current')], raw_tail: replacement)
    assert_metric report, 'Configured model', 'UNKNOWN'
    assert_metric report, 'Input', 50
  end
end

class UsageReviewCoverageTest < Minitest::Test
  include UsageFixture

  # A review snapshot that counted tokens but still said only "external reviewer
  # UNKNOWN" hid the local adversarial pass that those numbers belong to.
  # Break caught: a shell without a UTF-8 locale crashed on the first non-ASCII
  # byte in a Codex session, so review usage could not be reported at all.
  def test_reads_utf8_under_a_c_locale_and_reports_invalid_bytes_as_unreadable
    records = [{ type: 'response_item', payload: { text: 'Café — SENSITIVE' } }, context('current'),
               usage('current', 'current', 100)]
    invalid = %({"type":"turn_context","payload":{"turn_id":"other","model":"gpt-\xFF"}}\n).b +
              "#{JSON.generate(usage('other', 'other', 900))}\n"
    report = run_report(records, raw_tail: invalid, environment: { 'LC_ALL' => 'C', 'LANG' => 'C' })
    assert_metric report, 'Input', 100
    assert_includes report, 'Unreadable or unidentifiable records'
    refute_includes report, 'SENSITIVE'
  end

  def test_review_contribution_with_records_includes_local_adversarial_usage
    report = run_report([context('current'), usage('current', 'current', 100)], '--contribution', 'review')
    header = report.split('<details>').first
    assert_includes report, "#{COMMIT} / review"
    assert_includes header, 'Local adversarial reviewer usage: included below'
    assert_includes header, 'External reviewer/tool-model usage: UNKNOWN'
    refute_includes header, 'Local adversarial reviewer usage: UNKNOWN'
    assert_metric report, 'Input', 100
  end

  # Implementation tokens are not the adversarial pass. Claiming they are would
  # hide a missing review snapshot behind a green usage table.
  def test_implementation_snapshot_does_not_count_as_local_review
    header = run_report([context('current'), usage('current', 'current', 100)]).split('<details>').first
    assert_includes header, 'Local adversarial reviewer usage: UNKNOWN'
  end

  # Conflicting copies keep a response row whose usage is empty. Calling that
  # "included below" would advertise reviewer tokens that every metric lists as UNKNOWN.
  def test_review_contribution_with_uncountable_records_does_not_claim_inclusion
    report = run_report([context('current'), usage('replayed', 'current', 100),
                         usage('replayed', 'current', 200)], '--contribution', 'review')
    header = report.split('<details>').first
    assert_includes header, 'Local adversarial reviewer usage: UNKNOWN'
    refute_includes header, 'included below'
  end

  # The table needs every record in a group to carry a field. A header that looks
  # only at per-record fields can say "included below" over a table of UNKNOWN cells.
  def test_review_header_follows_printed_metric_cells
    first = usage('a', 'current', 100)
    first[:payload][:usage] = { input_tokens: 100 }
    second = usage('b', 'current', 20)
    second[:payload][:usage] = { output_tokens: 20 }
    header = run_report([context('current'), first, second], '--contribution', 'review').split('<details>').first
    assert_includes header, 'Local adversarial reviewer usage: UNKNOWN'
    refute_includes header, 'included below'
  end
end

class UsageFailuresTest < Minitest::Test
  include UsageFixture

  def test_all_turns_discloses_records_excluded_for_invalid_turn_identity
    [nil, '', '  ', 42].each do |turn|
      report = run_report([context('current'), usage('counted', 'current', 100),
                           usage('unattributed', turn, 9900)], '--all-turns')
      assert_includes report.split('<details>').first, 'Unreadable or unidentifiable records'
      assert_includes report, '| 100 |'
      refute_includes report, '9900'
    end
  end

  def test_missing_or_invalid_latest_turn_does_not_count_unattributed_responses
    [nil, '', 42].each do |turn|
      records = turn.nil? ? [] : [context(turn)]
      response = usage('unattributed', turn, 100)
      response[:payload].delete(:turn_id) if turn.nil?
      report = run_report([*records, response])
      assert_includes report, 'Responses: UNKNOWN'
      refute_includes report, '| 100 |'
    end
  end

  def test_discovery_handles_unsupported_session_metadata_as_unknown
    [nil, [], { type: 'session_meta', payload: [] }].each do |metadata|
      report = run_report([context('current'), usage('current', 'current', 100)], discover: true, metadata: metadata)
      assert_includes report, 'Responses: UNKNOWN'
    end
  end

  def test_malformed_token_payloads_stay_unknown_without_printing_the_bad_data
    [nil, 42, [], 'SENSITIVE'].each do |bad_usage|
      response = usage('current', 'current', 100)
      response[:payload][:usage] = bad_usage
      report = run_report([context('current'), response])
      assert_metric report, 'Effort', 'high'
      assert_metric report, 'Input', 'UNKNOWN'
      refute_includes report, 'SENSITIVE'
    end
  end

  def test_unavailable_native_records_and_unconfirmed_identity_report_unknown_instead_of_zero
    unsupported = [{ type: 'event_msg', payload: { type: 'token_count', info: { total_tokens: 9999 } } }]
    [run_report(unsupported),
     run_report([context('current'), usage('wrong-owner', 'current', 100)],
                discover: true, identity: 'different-thread')].each do |report|
      assert_includes report, 'Responses: UNKNOWN'
      refute_includes report, '0 responses'
      refute_includes report, '| 100 |'
    end
  end

  def test_public_report_rejects_unstructured_metadata_and_keeps_transcripts_private
    setting = context('current')
    setting[:payload].merge!(model: '<b>SENSITIVE-MODEL</b>', effort: "high\nSENSITIVE-EFFORT")
    response = usage('current', 'current', 100)
    response[:timestamp] = '/private/SENSITIVE-PATH'
    report = run_report([setting, response,
                         { type: 'response_item', payload: { content: 'SENSITIVE-PROMPT' } }])
    assert_metric report, 'Input', 100
    assert_includes report, 'source interval: UNKNOWN'
    refute_includes report, 'SENSITIVE'
    refute_includes report, '/private/'
  end

  def test_conflicting_copies_of_a_response_mark_counts_unknown
    report = run_report([context('current'), usage('replayed', 'current', 100), usage('replayed', 'current', 200)])
    assert_metric report, 'USD estimate', 'UNKNOWN'
    assert_includes report, 'Conflicting response copies'
    refute_includes report, '| 100 |'
  end

  def test_duplicate_attribution_conflicts_are_unknown_in_either_source_order
    original = context('current')
    changed = context('current')
    changed[:payload][:model] = 'other-model'
    reports = [[original, changed], [changed, original]].map do |first, second|
      run_report([first, usage('same', 'current', 100), second, usage('same', 'current', 100)])
    end
    assert_equal reports.first, reports.last
    assert_metric reports.first, 'USD estimate', 'UNKNOWN'
    assert_includes reports.first, 'Conflicting response copies'
  end

  def test_usage_without_matching_turn_context_does_not_inherit_another_turns_settings
    [[], [context('old')]].each do |records|
      report = run_report([*records, usage('current', 'current', 100)], '--turn', 'current')
      assert_metric report, 'Provider', 'openai'
      assert_metric report, 'Configured model', 'UNKNOWN'
      assert_metric report, 'Input', 100
    end
  end

  def test_invalid_commit_or_contribution_is_rejected_without_echoing_private_arguments
    [['--commit', '/private/SENSITIVE', '--contribution', 'implementation'],
     ['--commit', COMMIT, '--contribution', 'SENSITIVE'],
     ['--commit', COMMIT, '--contribution', 'implementation', '--all-turns', '--turn', 'old'], []].each do |arguments|
      output, error, status = Open3.capture3(COMMAND, 'usage', *arguments)
      refute_predicate status, :success?
      assert_empty output
      assert_includes error, 'shaka usage:'
      refute_includes error, 'SENSITIVE'
    end
  end
end

class MetricAssertTest < Minitest::Test
  def test_rejects_extra_trailing_cells
    assert_raises(Minitest::Assertion) { assert_metric("| Input | 300 | 999 |\n", 'Input', 300) }
    assert_metric("| Input | 300 |\n", 'Input', 300)
  end
end
