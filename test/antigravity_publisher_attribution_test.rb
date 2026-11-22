# frozen_string_literal: true

require_relative 'cli_publisher_attribution_test'

module AntigravityTranscriptFixture
  CONVERSATION = '00000000-0000-4000-8000-000000000006'

  private

  def with_transcript(*records)
    Dir.mktmpdir do |home|
      file = File.join(home, 'brain', CONVERSATION, '.system_generated', 'logs', 'transcript.jsonl')
      FileUtils.mkdir_p(File.dirname(file))
      lines = records.map { |record| record.is_a?(String) ? record : JSON.generate(record) }
      File.write(file, "#{lines.join("\n")}\n")
      yield({ 'ANTIGRAVITY_CONVERSATION_ID' => CONVERSATION, 'ANTIGRAVITY_APP_DATA_DIR' => home })
    end
  end

  def prompt(index) = { 'step_index' => index, 'type' => 'USER_INPUT', 'content' => 'SENSITIVE-PROMPT' }

  def response(index, model = 'gemini-4-argon-high')
    { 'step_index' => index, 'type' => 'PLANNER_RESPONSE', 'model' => model, 'input_tokens' => 100,
      'output_tokens' => 20 }.compact
  end

  def content
    { 'identity' => { 'agent' => 'Antigravity', 'provider' => 'Google', 'model' => 'UNKNOWN',
                      'effort' => 'UNKNOWN' },
      'provenance' => { 'active_model' => 'UNKNOWN', 'active_effort' => 'UNKNOWN' } }
  end
end

class AntigravityPublisherAttributionTest < Minitest::Test
  include AntigravityTranscriptFixture

  def test_configured_model_and_its_effort_fill_unknown_fields_without_a_note
    with_transcript(prompt(0), response(1, 'gemini-4-argon-low'), prompt(2), response(3), response(5)) do |session|
      result = prepare(session)
      assert_equal({ 'agent' => 'Antigravity', 'provider' => 'Google',
                     'model' => 'gemini-4-argon-high (configured)', 'effort' => 'high' }, result['identity'])
      assert_equal 'gemini-4-argon-high', result.dig('provenance', 'active_model')
      assert_equal 'high', result.dig('provenance', 'active_effort')
      assert_nil result['publisher_note']
    end
  end

  def test_conflicting_supplied_settings_are_refused
    with_transcript(prompt(0), response(1)) do |session|
      [%w[identity model], %w[identity effort], %w[provenance active_model]].each do |section, field|
        supplied = content
        supplied[section][field] = 'wrong'
        error = assert_raises(Shaka::Error) { Shaka::PublisherAttribution.prepare(supplied, environment: session) }
        assert_includes error.message, 'conflicts with native publisher settings'
      end
    end
  end

  def test_a_new_turn_without_a_response_does_not_inherit_the_previous_turn
    with_transcript(prompt(0), response(1), prompt(2)) do |session|
      result = prepare(session)
      assert_equal %w[UNKNOWN UNKNOWN], result.fetch('identity').values_at('model', 'effort')
      assert_includes result['publisher_note'], 'UNKNOWN model, effort: Antigravity current turn settings unavailable'
    end
  end

  def test_a_response_without_a_model_leaves_both_fields_unknown
    with_transcript(prompt(0), response(1), response(3, nil)) do |session|
      result = prepare(session)
      assert_equal %w[UNKNOWN UNKNOWN], result.fetch('identity').values_at('model', 'effort')
      assert_includes result['publisher_note'], 'UNKNOWN model, effort'
    end
  end

  def test_a_model_id_without_an_effort_segment_leaves_effort_unknown
    with_transcript(prompt(0), response(1, 'tuned-gateway-model')) do |session|
      result = prepare(session)
      assert_equal ['tuned-gateway-model (configured)', 'UNKNOWN'],
                   result.fetch('identity').values_at('model', 'effort')
      assert_includes result['publisher_note'], 'UNKNOWN effort: Antigravity model ID names no effort'
    end
  end

  def test_an_unreadable_line_anywhere_leaves_the_settings_unknown
    records = [prompt(0), '{"step_index": 1, SENSITIVE', response(2)]
    with_transcript(*records) do |session|
      result = prepare(session)
      assert_equal 'UNKNOWN', result.dig('identity', 'model')
      assert_includes result['publisher_note'], 'Antigravity transcript contains unreadable metadata'
    end
  end

  def test_a_step_without_a_readable_type_leaves_the_settings_unknown
    with_transcript(prompt(0), response(1), '{"step_index": 2, "type": null}') do |session|
      result = prepare(session)
      assert_equal 'UNKNOWN', result.dig('identity', 'model')
      assert_includes result['publisher_note'], 'Antigravity transcript contains unreadable metadata'
    end
  end

  def test_a_response_before_any_user_step_belongs_to_no_turn
    with_transcript(response(0)) do |session|
      result = prepare(session)
      assert_equal 'UNKNOWN', result.dig('identity', 'model')
      assert_includes result['publisher_note'], 'UNKNOWN model, effort: Antigravity transcript has no user turn'
    end
  end

  def test_an_earlier_step_written_again_does_not_join_the_current_turn
    earlier = response(1, 'gemini-4-argon-low')
    with_transcript(prompt(0), earlier, prompt(2), earlier) do |session|
      assert_equal 'UNKNOWN', prepare(session).dig('identity', 'model')
    end
  end

  def test_a_missing_transcript_names_the_reason
    Dir.mktmpdir do |home|
      session = { 'ANTIGRAVITY_CONVERSATION_ID' => CONVERSATION, 'ANTIGRAVITY_APP_DATA_DIR' => home }
      assert_includes prepare(session)['publisher_note'], 'UNKNOWN model, effort: Antigravity transcript unavailable'
    end
  end

  def test_a_second_host_marker_keeps_supplied_attribution_unverified
    with_transcript(prompt(0), response(1)) do |session|
      result = prepare(session.merge('CLAUDE_CODE_SESSION_ID' => 'outer-claude-session'))
      assert_equal content['identity'], result['identity']
      assert_includes result['publisher_note'], 'supplied attribution is unverified'
    end
  end

  private

  def prepare(session) = Shaka::PublisherAttribution.prepare(content, environment: session)
end

# `shaka description` and `shaka reply` are the callers a real publication uses.
class AntigravityCliPublisherAttributionTest < Minitest::Test
  include AntigravityTranscriptFixture
  include CliOpeningCheckFakes
  include CliPublicationRun

  SUMMARY = 'Antigravity attribution comes from the conversation transcript.'
  LEAKED = /unverified|SENSITIVE|#{CONVERSATION}/

  def test_description_publishes_transcript_settings_without_a_note
    with_transcript(prompt(0), response(1)) do |session|
      run_publication(session) do |dir, output, error, status|
        assert_predicate status, :success?, "#{output}\n#{error}"
        body = File.read(File.join(dir, 'published.md'))
        assert_includes body, 'Antigravity · Google · gemini-4-argon-high (configured) · high'
        assert_includes body, '| Active model / effort | gemini-4-argon-high / high |'
        refute_match(LEAKED, body)
      end
    end
  end

  def test_reply_keeps_a_note_when_the_current_turn_has_no_response
    with_transcript(prompt(0), response(1), prompt(2)) do |session|
      run_publication(session, command: 'reply') do |dir, _output, error, status|
        assert_predicate status, :success?, error
        body = File.read(File.join(dir, 'published.md'))
        assert_includes body, 'Antigravity · Google · UNKNOWN · UNKNOWN'
        assert_includes body, '_UNKNOWN model, effort: Antigravity current turn settings unavailable._'
      end
    end
  end

  private

  def description_content = super.merge('identity' => content.fetch('identity'))
end
