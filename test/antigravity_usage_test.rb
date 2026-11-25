# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/publication/text'

module AntigravityUsageFixture
  COMMAND = SHAKA_COMMAND
  COMMIT = 'a' * 40
  CONVERSATION = '00000000-0000-4000-8000-000000000005'
  CLEAR = { 'ANTIGRAVITY_CONVERSATION_ID' => nil, 'ANTIGRAVITY_APP_DATA_DIR' => nil, 'CODEX_THREAD_ID' => nil,
            'CLAUDE_CODE_SESSION_ID' => nil, 'CURSOR_CONVERSATION_ID' => nil, 'OPENCODE_SESSION_ID' => nil,
            'PI_CODING_AGENT' => nil }.freeze
  REDACTED_OUTPUT = /SENSITIVE|#{Regexp.escape(CONVERSATION)}|brain/

  private

  def step(index, type, second, **fields)
    { step_index: index, source: type == 'USER_INPUT' ? 'USER_EXPLICIT' : 'MODEL', type: type, status: 'DONE',
      created_at: "2026-11-22T16:57:#{second}Z", **fields }
  end

  def prompt(index, second) = step(index, 'USER_INPUT', second, content: 'SENSITIVE-PROMPT')

  def response(index, second, input, model: 'gemini-4-argon-high', **fields)
    step(index, 'PLANNER_RESPONSE', second, model: model, input_tokens: input, cache_read_tokens: 40,
                                            output_tokens: 20, content: 'SENSITIVE-RESPONSE', **fields).compact
  end

  # A step that is not a model response, even if it ever carried a counter key.
  def tool_output(index, second) = step(index, 'GENERIC', second, content: 'SENSITIVE-TOOL-OUTPUT', input_tokens: nil)

  # The step Antigravity writes when it compacts a conversation: counters, but no model.
  def checkpoint(index, second)
    step(index, 'CHECKPOINT', second, input_tokens: 500, cache_read_tokens: 60, output_tokens: 70,
                                      content: 'SENSITIVE-SUMMARY')
  end

  def two_turns
    [prompt(0, '10'), response(1, '11', 900, model: 'gemini-4-argon-low'),
     prompt(2, '20'), response(3, '21', 100), tool_output(4, '22'), response(5, '23', 200)]
  end

  def write_transcript(home, records, conversation: CONVERSATION)
    file = File.join(home, 'brain', conversation, '.system_generated', 'logs', 'transcript.jsonl')
    FileUtils.mkdir_p(File.dirname(file))
    lines = records.map { |record| record.is_a?(String) ? record : JSON.generate(record) }
    File.write(file, "#{lines.join("\n")}\n")
    file
  end

  def capture_report(*, environment: {})
    Open3.capture3(CLEAR.merge(environment), *COMMAND, 'usage', '--commit', COMMIT,
                   '--contribution', 'implementation', *)
  end

  def report(*, environment: {})
    output, error, status = capture_report(*, environment: environment)
    assert_predicate status, :success?, error
    output
  end

  def session(home) = { 'ANTIGRAVITY_CONVERSATION_ID' => CONVERSATION, 'ANTIGRAVITY_APP_DATA_DIR' => home }

  def explicit(file, *) = report('--host', 'antigravity', '--file', file, *)
end

class AntigravityUsageTest < Minitest::Test
  include AntigravityUsageFixture
  include MetricAssert

  def test_detects_antigravity_and_reports_the_latest_turn
    Dir.mktmpdir do |home|
      write_transcript(home, two_turns)
      output = report(environment: session(home))
      assert_latest_turn(output)
      assert_includes output, '2 responses'
      assert_includes output, 'Source selection: host context'
      assert_includes output, 'latest user turn of the conversation'
      refute_match(REDACTED_OUTPUT, without_usage_identity(output))
    end
  end

  def test_a_transcript_without_models_keeps_its_tokens
    Dir.mktmpdir do |home|
      output = explicit(write_transcript(home, [prompt(0, '10'), response(1, '11', 300, model: nil)]))
      assert_metric output, 'Configured model', 'UNKNOWN'
      assert_metric output, 'Effort', 'UNKNOWN'
      assert_metric output, 'Input', 300
    end
  end

  # The transcript records no cache writes, which Anthropic bills separately, so a Claude
  # model names no provider here and stays unpriced.
  def test_a_claude_model_stays_unpriced
    Dir.mktmpdir do |home|
      records = [prompt(0, '10'), response(1, '11', 300, model: 'claude-sonnet-5-5-low')]
      output = explicit(write_transcript(home, records))
      assert_metric output, 'Provider', 'UNKNOWN'
      assert_metric output, 'Effort', 'low'
      assert_metric output, 'USD estimate', 'UNKNOWN'
      assert_includes output, 'Unsupported provider or configured model'
      refute_includes output, 'Cache-exclusive input is unpriced'
      refute_includes output, 'Anthropic API list prices'
    end
  end

  def test_a_usage_header_names_google_like_other_providers
    header = Shaka::PublicationText.identity('agent' => 'Antigravity', 'provider' => 'google',
                                             'model' => 'gemini-4-argon-high', 'effort' => 'high')
    assert_includes header, ' · Google · '
  end

  def test_a_model_id_without_an_effort_segment_reports_no_effort
    Dir.mktmpdir do |home|
      records = [prompt(0, '10'), response(1, '11', 300, model: 'tuned-gateway-model')]
      output = explicit(write_transcript(home, records))
      assert_metric output, 'Configured model', 'tuned-gateway-model'
      assert_metric output, 'Effort', 'UNKNOWN'
    end
  end

  def test_a_model_id_that_publication_refuses_supplies_no_model_or_effort
    Dir.mktmpdir do |home|
      ['www.example.test-high', 'vendor/model-high', "#{'m' * 80}-high", 'UNKNOWN'].each do |model|
        output = explicit(write_transcript(home, [prompt(0, '10'), response(1, '11', 300, model: model)]))
        assert_metric output, 'Configured model', 'UNKNOWN'
        assert_metric output, 'Effort', 'UNKNOWN'
        assert_metric output, 'Input', 300
      end
    end
  end

  def test_an_empty_marker_leaves_another_host_selected
    Dir.mktmpdir do |home|
      environment = { 'ANTIGRAVITY_CONVERSATION_ID' => '', 'CLAUDE_CODE_SESSION_ID' => 'outer-claude-session',
                      'CLAUDE_CONFIG_DIR' => home }
      assert_includes report(environment: environment), 'Claude Code source versions'
    end
  end

  def test_mixed_host_context_requires_an_explicit_host
    Dir.mktmpdir do |home|
      write_transcript(home, two_turns)
      environment = session(home).merge('CLAUDE_CODE_SESSION_ID' => 'outer-claude-session')
      output, error, status = capture_report(environment: environment)
      refute_predicate status, :success?
      assert_empty output
      assert_includes error, 'invalid options'
      assert_latest_turn(report('--host', 'antigravity', environment: environment))
    end
  end

  private

  def assert_latest_turn(output)
    assert_metric output, 'Provider', 'google'
    assert_metric output, 'Configured model', 'gemini-4-argon-high'
    assert_metric output, 'Routed model', 'UNKNOWN'
    assert_metric output, 'Effort', 'high'
    assert_metric output, 'Input', 300
    assert_metric output, 'Cached input', 80
    assert_metric output, 'Output', 40
    assert_metric output, 'Reasoning output', 'UNKNOWN'
    assert_metric output, 'Cache writes', 'UNKNOWN'
    # Gemini 4 Argon before December 1, 2026: 300 input at $2, 80 cache reads at $0.10, 40 output at $10.
    assert_metric output, 'USD estimate', '$0.001008'
  end
end

class AntigravityTurnSelectionTest < Minitest::Test
  include AntigravityUsageFixture
  include MetricAssert

  def test_all_turns_and_explicit_turns_select_by_user_input_step
    Dir.mktmpdir do |home|
      file = write_transcript(home, two_turns)
      all = explicit(file, '--all-turns')
      assert_includes all, '3 responses'
      assert_metric all, 'Input', 900, 300
      assert_metric all, 'Effort', 'low', 'high'
      assert_metric explicit(file, '--turn', '0'), 'Input', 900
    end
  end

  def test_a_mistyped_turn_names_the_field_to_use
    Dir.mktmpdir do |home|
      _output, error, status = capture_report('--host', 'antigravity', '--file', write_transcript(home, two_turns),
                                              '--turn', '7')
      refute_predicate status, :success?
      assert_includes error, 'antigravity turns use the USER_INPUT step_index field'
    end
  end

  def test_a_step_that_carries_counters_without_a_model_is_counted
    Dir.mktmpdir do |home|
      output = explicit(write_transcript(home, [prompt(0, '10'), response(1, '11', 300), checkpoint(2, '12'),
                                                tool_output(3, '13'), response(4, '14', 100)]))
      assert_includes output, '3 responses'
      assert_metric output, 'Configured model', 'gemini-4-argon-high', 'UNKNOWN'
      assert_metric output, 'Input', 400, 500
      assert_metric output, 'Cached input', 80, 60
      assert_metric output, 'Output', 40, 70
      refute_match(REDACTED_OUTPUT, without_usage_identity(output))
    end
  end

  def test_a_second_transcript_is_refused
    Dir.mktmpdir do |home|
      file = write_transcript(home, two_turns)
      output, error, status = capture_report('--host', 'antigravity', '--file', file, '--file', file)
      refute_predicate status, :success?
      assert_empty output
      assert_includes error, 'Antigravity usage reads one transcript per run'
    end
  end

  def test_a_step_written_again_keeps_its_place_and_its_last_line
    Dir.mktmpdir do |home|
      rewritten = [*two_turns, prompt(0, '40'), response(1, '41', 950, model: 'gemini-4-argon-low')]
      file = write_transcript(home, rewritten)
      assert_metric explicit(file), 'Input', 300
      assert_metric explicit(file, '--all-turns'), 'Input', 950, 300
    end
  end

  def test_since_time_keeps_responses_from_the_cutoff_second
    Dir.mktmpdir do |home|
      output = explicit(write_transcript(home, two_turns), '--since-time', '2026-11-22T16:57:21.500Z')
      assert_includes output, '2 responses'
      assert_metric output, 'Input', 300
    end
  end
end

class AntigravityUnreadableUsageTest < Minitest::Test
  include AntigravityUsageFixture
  include MetricAssert

  def test_a_transcript_outside_the_conversation_layout_is_unidentifiable
    Dir.mktmpdir do |home|
      copy = File.join(home, 'saved.jsonl')
      FileUtils.cp(write_transcript(home, two_turns), copy)
      assert_unavailable(explicit(copy, '--all-turns'))
    end
  end

  def test_a_missing_transcript_reports_no_responses
    Dir.mktmpdir do |home|
      assert_unavailable(report('--host', 'antigravity', environment: session(home)))
      assert_unavailable(explicit(File.join(home, 'brain', CONVERSATION, '.system_generated', 'logs', 'gone.jsonl')))
    end
  end

  def test_a_named_pipe_in_the_conversation_layout_is_not_opened
    skip 'needs named pipes' unless File.respond_to?(:mkfifo)
    Dir.mktmpdir do |home|
      pipe = File.join(File.dirname(write_transcript(home, two_turns)), 'pipe.jsonl')
      File.mkfifo(pipe)
      writer = Thread.new { release_reader(pipe) }
      assert_unavailable(explicit(pipe, '--all-turns'))
    ensure
      writer&.kill
    end
  end

  def test_a_relative_data_directory_is_not_searched
    Dir.mktmpdir do |home|
      write_transcript(home, two_turns)
      environment = session(home).merge('ANTIGRAVITY_APP_DATA_DIR' => File.basename(home))
      output, _error, _status = Open3.capture3(CLEAR.merge(environment), *COMMAND, 'usage', '--commit', COMMIT,
                                               '--contribution', 'implementation', chdir: File.dirname(home))
      assert_unavailable(output)
    end
  end

  def test_an_unreadable_line_hides_a_turn_boundary_so_nothing_is_counted
    Dir.mktmpdir do |home|
      unreadable_lines.each do |line|
        file = write_transcript(home, [prompt(0, '10'), response(1, '11', 900), line, response(3, '21', 100)])
        assert_unavailable(explicit(file))
        assert_unavailable(explicit(file, '--turn', '0'))
      end
    end
  end

  def test_a_counter_that_is_not_a_whole_number_is_unknown_and_never_zero
    Dir.mktmpdir do |home|
      output = explicit(write_transcript(home, [prompt(0, '10'), response(1, '11', 300), response(2, '12', '999')]))
      assert_includes output, '2 responses'
      assert_metric output, 'Input', 'UNKNOWN'
      assert_metric output, 'Output', 40
      refute_match(/999|SENSITIVE/, without_usage_identity(output))
    end
  end

  def test_a_response_before_any_user_input_has_no_turn
    Dir.mktmpdir do |home|
      output = explicit(write_transcript(home, [response(0, '10', 999), prompt(1, '11'), response(2, '12', 300)]),
                        '--all-turns')
      assert_includes output, '1 responses'
      assert_includes output, 'Unreadable or unidentifiable records'
      assert_metric output, 'Input', 300
    end
  end

  private

  # A reader that opened the pipe would block until a writer appears. This supplies one, so a
  # regression fails the assertion instead of hanging the suite.
  def release_reader(pipe)
    sleep 5
    File.open(pipe, File::WRONLY | File::NONBLOCK) { nil }
  rescue SystemCallError
    nil
  end

  # A user step that is not JSON, then steps without a whole-number index or a readable type.
  def unreadable_lines
    steps = [response('x', '13', 999), response(4, '14', 999).merge(type: nil),
             response(5, '15', 999).merge(type: ' ')]
    [JSON.generate(prompt(2, '20')).sub('"USER_INPUT"', 'USER_INPUT'), *steps.map { |step| JSON.generate(step) }]
  end

  def assert_unavailable(output)
    assert_includes output, 'Responses: UNKNOWN'
    assert_includes output, 'Unreadable or unidentifiable records'
    refute_match(/900|999|SENSITIVE/, without_usage_identity(output))
  end
end
