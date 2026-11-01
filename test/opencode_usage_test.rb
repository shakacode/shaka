# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'open3'
require 'time'

module OpencodeUsageFixture
  COMMAND = SHAKA_COMMAND
  COMMIT = 'a' * 40
  SESSION = 'ses_0123456789abcdefABCDEF'
  CLEAR = { 'PI_CODING_AGENT' => nil, 'CODEX_THREAD_ID' => nil, 'CLAUDE_CODE_SESSION_ID' => nil,
            'CURSOR_CONVERSATION_ID' => nil, 'OPENCODE_SESSION_ID' => nil }.freeze
  OLD_USER = 'msg-old-user'
  NEW_USER = 'msg-new-user'
  ROW = <<~ROW.chomp
    | Metric | opencode |
    | --- | --- |
    | Provider | opencode |
    | Configured model | session-model |
    | Routed model | routed-model |
    | Effort | medium |
    | Input | 475 |
    | Cached input | 9201 |
    | Output | 314 |
    | Reasoning output | 5 |
    | Cache writes | 0 |
    | Native total | 9995 |
  ROW

  private

  def tokens(input, read, output, reasoning: 0, write: 0)
    { 'total' => input + read + output + reasoning + write, 'input' => input, 'output' => output,
      'reasoning' => reasoning, 'cache' => { 'read' => read, 'write' => write } }
  end

  def user_message(identity, created)
    { 'info' => { 'role' => 'user', 'id' => identity, 'time' => { 'created' => created } },
      'parts' => [{ 'type' => 'text', 'text' => 'SENSITIVE-TASK' }] }
  end

  def assistant_message(identity, parent, created, completed, message_tokens)
    { 'info' => { 'role' => 'assistant', 'id' => identity, 'parentID' => parent, 'agent' => 'build',
                  'modelID' => 'routed-model', 'providerID' => 'opencode', 'variant' => 'medium',
                  'tokens' => message_tokens, 'time' => { 'created' => created, 'completed' => completed } },
      'parts' => [{ 'type' => 'step', 'snapshot' => 'SENSITIVE-DIFF' }] }
  end

  def latest_fixture
    { 'info' => { 'version' => '1.18.31', 'model' => { 'id' => 'session-model' } },
      'messages' => [
        user_message(OLD_USER, 1_789_660_200_000),
        assistant_message('resp-old', OLD_USER, 1_789_660_200_001, 1_789_660_200_002, tokens(900, 0, 20)),
        user_message(NEW_USER, 1_789_660_287_052),
        assistant_message('resp-new', NEW_USER, 1_789_660_287_053, 1_789_660_292_357,
                          tokens(475, 9201, 314, reasoning: 5))
      ] }
  end

  def single_fixture(message, version: '1.18.31')
    { 'info' => { 'version' => version, 'model' => { 'id' => 'session-model' } },
      'messages' => [user_message(NEW_USER, 1_789_660_287_052), message] }
  end

  def write_export(directory, document, name: 'export.json')
    path = File.join(directory, name)
    File.write(path, JSON.generate(document))
    path
  end

  def report(*arguments, environment: {})
    args = [CLEAR.merge(environment), *COMMAND, 'usage', '--commit', COMMIT, '--contribution', 'implementation',
            *arguments]
    output, error, status = Open3.capture3(*args)
    assert_predicate status, :success?, error
    output
  end

  # OpenCode 1.x has `export`; the stub records any `api` call it should never receive.
  def stub_opencode(directory, document)
    executable = File.join(directory, 'opencode')
    export = write_export(directory, document, name: 'stub-export.json')
    File.write(executable, <<~SH)
      #!/bin/sh
      [ "$1" = --version ] && { echo 1.18.31; exit 0; }
      [ "$1" = api ] && { touch #{File.join(directory, 'api-called')}; exit 1; }
      cat #{export}
    SH
    File.chmod(0o755, executable)
  end

  def stub_environment(directory)
    { 'PATH' => "#{directory}:#{ENV.fetch('PATH')}" }
  end
end

class OpencodeSinceTimeTest < Minitest::Test
  include OpencodeUsageFixture

  def test_keeps_a_response_after_a_cutoff_in_the_same_second
    Dir.mktmpdir do |directory|
      millis = 1_789_660_292_357
      file = same_second_export(directory, millis)
      cutoff = Time.at(Rational(millis - 100, 1000)).utc.iso8601(3)

      output = report('--host', 'opencode', '--file', file, '--since-time', cutoff)

      assert_metric output, 'Input', 475
    end
  end

  def test_refuses_to_undercount_a_response_without_an_identity_or_parent_turn
    %i[id parent].each do |missing|
      Dir.mktmpdir do |directory|
        file = same_second_export(directory, 1_789_660_292_357, missing:)
        args = ['usage', '--host', 'opencode', '--file', file, '--commit', COMMIT,
                '--contribution', 'implementation', '--since-time', '2026-09-17T15:51:32.057Z']
        output, error, status = Open3.capture3(CLEAR, *COMMAND, *args)

        assert_equal [false, '', true],
                     [status.success?, output, error.include?('--since-time cannot scope incomplete native sources')]
      end
    end
  end

  private

  def same_second_export(directory, millis, missing: nil)
    later = assistant_message('resp-new', NEW_USER, millis - 1, millis, tokens(475, 0, 20))
    earlier = assistant_message(missing == :id ? nil : 'resp-earlier', missing == :parent ? nil : NEW_USER,
                                millis - 200, millis - 157,
                                tokens(900, 0, 20))
    document = single_fixture(later)
    document['messages'].insert(1, earlier)
    write_export(directory, document)
  end
end

class OpencodeUsageTest < Minitest::Test
  include OpencodeUsageFixture

  def test_counts_each_response_once_from_the_latest_turn
    Dir.mktmpdir do |directory|
      output = report('--host', 'opencode', '--file', write_export(directory, latest_fixture))
      assert_includes output, ROW
      assert_includes output, '1 responses'
      assert_includes output.split('<details>').first, 'latest user turn'
      refute_includes output, '| 900 | 0 | 20 |'
      refute_match(/SENSITIVE|resp-|msg-/, output)
    end
  end

  def test_reports_versions_cost_limits_and_scope
    Dir.mktmpdir do |directory|
      output = report('--host', 'opencode', '--file', write_export(directory, latest_fixture))
      assert_includes output, 'OpenCode source versions: 1.18.31'
      assert_includes output, 'Input excludes cache reads and writes'
      assert_metric output, 'USD estimate', 'UNKNOWN'
      assert_includes output, 'Cache-exclusive input is unpriced'
      assert_includes output, '2026-'
    end
  end

  def test_selects_all_or_explicit_turns
    Dir.mktmpdir do |directory|
      file = write_export(directory, latest_fixture)
      assert_includes report('--host', 'opencode', '--file', file, '--all-turns'), '| Input | 1375 |'
      assert_includes report('--host', 'opencode', '--file', file, '--turn', OLD_USER), '| Input | 900 |'
      assert_includes report('--host', 'opencode', '--file', file, '--turn', NEW_USER), ROW
    end
  end

  def test_discovers_the_session_through_host_context
    Dir.mktmpdir do |directory|
      stub_opencode(directory, latest_fixture)
      env = stub_environment(directory).merge('OPENCODE_SESSION_ID' => SESSION)
      output = report(environment: env)
      assert_includes output, ROW
      assert_includes output, 'host context'
      refute_includes output, SESSION
    end
  end

  def test_explicit_session_exports_without_a_file
    Dir.mktmpdir do |directory|
      stub_opencode(directory, latest_fixture)
      output = report('--host', 'opencode', '--session', SESSION, environment: stub_environment(directory))
      assert_includes output, ROW
      assert_includes output, 'explicit files'
      refute_includes output, SESSION
    end
  end

  def test_a_failed_1x_export_never_tries_the_v2_api
    Dir.mktmpdir do |directory|
      stub_opencode(directory, latest_fixture)
      File.delete(File.join(directory, 'stub-export.json'))
      output = report('--host', 'opencode', '--session', SESSION, environment: stub_environment(directory))
      assert_includes output, 'OpenCode export failed'
      refute_path_exists File.join(directory, 'api-called')
    end
  end

  def test_an_unreadable_version_keeps_the_1x_export
    Dir.mktmpdir do |directory|
      stub_opencode(directory, latest_fixture)
      executable = File.join(directory, 'opencode')
      File.write(executable, File.read(executable).sub('echo 1.18.31; exit 0', 'exit 1'))
      output = report('--host', 'opencode', '--session', SESSION, environment: stub_environment(directory))
      assert_includes output, ROW
      refute_path_exists File.join(directory, 'api-called')
    end
  end

  def test_openai_provider_responses_are_never_priced_from_cache_inclusive_rates
    Dir.mktmpdir do |directory|
      priced = assistant_message('resp-new', NEW_USER, 1_789_660_287_053, 1_789_660_292_357,
                                 tokens(100_000, 10_000, 1_000))
      priced['info'].merge!('providerID' => 'openai', 'modelID' => 'gpt-5.6-sol')
      document = single_fixture(priced).tap { |export| export['info']['model']['id'] = 'gpt-5.6-sol' }
      output = report('--host', 'opencode', '--file', write_export(directory, document))
      assert_metric output, 'USD estimate', 'UNKNOWN'
      assert_includes output, 'Cache-exclusive input is unpriced'
      refute_includes output, '$0.384000'
    end
  end

  def test_configured_model_falls_back_to_unknown
    Dir.mktmpdir do |directory|
      document = latest_fixture
      document['info'].delete('model')
      output = report('--host', 'opencode', '--file', write_export(directory, document))
      assert_metric output, 'Configured model', 'UNKNOWN'
      assert_metric output, 'Routed model', 'routed-model'
      assert_metric output, 'Input', 475
    end
  end
end

module OpencodeV2UsageFixture
  include OpencodeUsageFixture

  private

  def v2_user(identity, created)
    { 'type' => 'user', 'id' => identity, 'time' => { 'created' => created }, 'text' => 'SENSITIVE-TASK' }
  end

  def v2_assistant(identity, created, completed, message_tokens)
    { 'type' => 'assistant', 'id' => identity, 'agent' => 'build',
      'model' => { 'id' => 'routed-model', 'providerID' => 'opencode', 'variant' => 'medium' },
      'tokens' => message_tokens.except('total'), 'cost' => 0.01,
      'time' => { 'created' => created, 'completed' => completed },
      'content' => [{ 'type' => 'text', 'text' => 'SENSITIVE-REPLY' }] }
  end

  # A running compaction has no tokens yet; completed and failed ones report them.
  def v2_compaction(identity, message_tokens = nil)
    compaction = { 'type' => 'compaction', 'id' => identity, 'status' => message_tokens ? 'completed' : 'running',
                   'time' => { 'created' => 1_789_660_292_358 }, 'summary' => 'SENSITIVE-SUMMARY' }
    return compaction unless message_tokens

    model = { 'id' => 'routed-model', 'providerID' => 'opencode', 'variant' => 'medium' }
    compaction.merge('tokens' => message_tokens.except('total'), 'model' => model)
  end

  def v2_fixture
    { 'data' => { 'info' => { 'id' => SESSION, 'model' => { 'id' => 'session-model' } },
                  'messages' => [
                    v2_user(OLD_USER, 1_789_660_200_000),
                    v2_assistant('resp-old', 1_789_660_200_001, 1_789_660_200_002, tokens(900, 0, 20)),
                    v2_user(NEW_USER, 1_789_660_287_052),
                    v2_assistant('resp-new', 1_789_660_287_053, 1_789_660_292_357,
                                 tokens(475, 9201, 314, reasoning: 5)),
                    { 'type' => 'idle', 'id' => 'msg-idle', 'time' => { 'created' => 1_789_660_292_358 } }
                  ] } }
  end

  # OpenCode v2 removed `export`; its API reports the session through `opencode api get`.
  def stub_opencode_v2(directory, document)
    executable = File.join(directory, 'opencode')
    export = write_export(directory, document, name: 'stub-export.json')
    route = "/api/experimental/session/#{SESSION}/export"
    File.write(executable, <<~SH)
      #!/bin/sh
      [ "$1" = --version ] && { echo opencode v2.0.32; exit 0; }
      [ "$1 $2 $3" = "api get #{route}" ] || exit 1
      cat #{export}
    SH
    File.chmod(0o755, executable)
  end
end

class OpencodeV2UsageTest < Minitest::Test
  include OpencodeV2UsageFixture

  V2_ROW = ROW.sub('| Native total | 9995 |', '| Native total | UNKNOWN |')

  def test_reads_a_discovered_session_through_the_v2_api
    Dir.mktmpdir do |directory|
      stub_opencode_v2(directory, v2_fixture)
      output = report(environment: stub_environment(directory).merge('OPENCODE_SESSION_ID' => SESSION))
      assert_includes output, V2_ROW
      assert_includes output, '1 responses'
      refute_includes output, 'OpenCode export failed'
      refute_match(/SENSITIVE|resp-|msg-|#{SESSION}/o, output)
    end
  end

  def test_assigns_each_response_to_the_preceding_user_message
    Dir.mktmpdir do |directory|
      file = write_export(directory, v2_fixture)
      assert_includes report('--host', 'opencode', '--file', file), V2_ROW
      assert_includes report('--host', 'opencode', '--file', file, '--turn', OLD_USER), '| Input | 900 |'
      assert_includes report('--host', 'opencode', '--file', file, '--all-turns'), '| Input | 1375 |'
    end
  end

  def test_a_response_before_any_user_message_has_no_turn
    Dir.mktmpdir do |directory|
      document = v2_fixture
      document['data']['messages'].unshift(v2_assistant('resp-orphan', 1, 2, tokens(7, 0, 1)))
      output = report('--host', 'opencode', '--file', write_export(directory, document), '--all-turns')
      assert_includes output, '| Input | 1375 |'
      assert_includes output, 'Unreadable or unidentifiable records'
    end
  end

  def test_counts_a_billed_compaction_in_its_turn
    Dir.mktmpdir do |directory|
      document = v2_fixture
      document['data']['messages'].push(v2_compaction('compaction-new', tokens(25, 100, 50)),
                                        v2_compaction('compaction-running'))
      output = report('--host', 'opencode', '--file', write_export(directory, document))
      assert_includes output, '2 responses'
      assert_metric output, 'Input', 500
      refute_includes output, 'SENSITIVE'
    end
  end

  def test_skips_an_interrupted_response_that_reports_no_tokens
    Dir.mktmpdir do |directory|
      document = v2_fixture
      interrupted = v2_assistant('resp-interrupted', 1_789_660_292_360, 1_789_660_292_361, tokens(0, 0, 0))
      interrupted = interrupted.except('tokens').merge('finish' => 'error', 'error' => { 'type' => 'aborted' })
      document['data']['messages'].push(interrupted)
      output = report('--host', 'opencode', '--file', write_export(directory, document))
      assert_includes output, V2_ROW
      assert_includes output, '1 responses'
    end
  end

  def test_a_v2_export_without_a_message_list_is_unreadable
    Dir.mktmpdir do |directory|
      output = report('--host', 'opencode', '--file', write_export(directory, { 'data' => { 'messages' => 'x' } }))
      assert_includes output, 'Responses: UNKNOWN'
      assert_includes output, 'Unreadable or unidentifiable records'
    end
  end
end

class OpencodeUsageFailuresTest < Minitest::Test
  include OpencodeUsageFixture

  def test_missing_token_fields_stay_unknown_without_zero_inflation
    Dir.mktmpdir do |directory|
      broken = tokens(100, 40, 20)
      broken['cache'].delete('read')
      message = assistant_message('resp-new', NEW_USER, 1_789_660_287_053, 1_789_660_292_357, broken)
      output = report('--host', 'opencode', '--file', write_export(directory, single_fixture(message)))
      assert_metric output, 'Input', 100
      assert_metric output, 'Cached input', 'UNKNOWN'
      assert_metric output, 'Native total', 160
      refute_includes output, 'SENSITIVE'
    end
  end

  def test_conflicting_copies_of_a_response_mark_counts_unknown
    Dir.mktmpdir do |directory|
      first = assistant_message('resp-new', NEW_USER, 1_789_660_287_053, 1_789_660_292_357, tokens(475, 0, 20))
      second = assistant_message('resp-new', NEW_USER, 1_789_660_287_053, 1_789_660_292_357, tokens(100, 0, 20))
      args = ['--host', 'opencode', '--file', write_export(directory, single_fixture(first)),
              '--file', write_export(directory, single_fixture(second), name: 'second.json')]
      output = report(*args)
      assert_metric output, 'Input', 'UNKNOWN'
      assert_includes output, 'Conflicting response copies'
      refute_includes output, '| 475 |'
    end
  end

  def test_malformed_export_is_disclosed_without_printing_transcripts
    Dir.mktmpdir do |directory|
      file = File.join(directory, 'export.json')
      File.write(file, '{"messages": [SENSITIVE-INCOMPLETE')
      output = report('--host', 'opencode', '--file', file)
      assert_includes output, 'Responses: UNKNOWN'
      assert_includes output, 'Unreadable or unidentifiable records'
      refute_includes output, 'SENSITIVE'
    end
  end

  def test_time_that_is_not_an_object_is_disclosed_as_unreadable
    Dir.mktmpdir do |directory|
      user = user_message(NEW_USER, 0)
      user['info']['time'] = 'bad'
      message = assistant_message('resp-new', NEW_USER, 0, 0, tokens(475, 0, 20))
      message['info']['time'] = 5
      output = report('--host', 'opencode', '--file', write_export(directory, { 'messages' => [user, message] }))
      assert_includes output, 'Native usage is PARTIAL'
      assert_includes output, 'Unreadable or unidentifiable records'
      refute_includes output, 'SENSITIVE'
    end
  end

  def test_failed_export_stays_unknown
    Dir.mktmpdir do |directory|
      executable = File.join(directory, 'opencode')
      File.write(executable, "#!/bin/sh\necho 'no such session' >&2\nexit 1\n")
      File.chmod(0o755, executable)
      output = report('--host', 'opencode', '--session', SESSION, environment: stub_environment(directory))
      assert_includes output, 'Responses: UNKNOWN'
      assert_includes output, 'OpenCode export failed'
      refute_includes output, 'Unreadable or unidentifiable records'
    end
  end

  def test_rejects_an_invalid_session_without_calling_opencode
    Dir.mktmpdir do |directory|
      sentinel = File.join(directory, 'called')
      executable = File.join(directory, 'opencode')
      File.write(executable, "#!/bin/sh\ntouch #{sentinel}\n")
      File.chmod(0o755, executable)
      output = report('--host', 'opencode', '--session', '../../etc/passwd', environment: stub_environment(directory))
      assert_includes output, 'Pass an OpenCode session with --session ID'
      refute_path_exists sentinel
    end
  end

  def test_missing_session_context_names_the_session_flag
    Dir.mktmpdir do |directory|
      executable = File.join(directory, 'opencode')
      File.write(executable, "#!/bin/sh\nexit 1\n")
      File.chmod(0o755, executable)
      output = report('--host', 'opencode', environment: stub_environment(directory))
      assert_includes output, 'Responses: UNKNOWN'
      assert_includes output, 'Pass an OpenCode session with --session ID.'
    end
  end
end
