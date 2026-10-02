# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'open3'
require 'shaka/usage/cursor_usage'
require_relative 'cli_opening_check_fakes'

# Builds the empty report, the fake GitHub CLI, and the stop-hook environment.
module CursorUsageRefreshFixture
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  HOOK = File.expand_path('../skills/shaka/scripts/cursor-usage-hook', __dir__)
  COMMIT = 'a' * 40
  SESSION = '11111111-1111-4111-8111-111111111111'
  GENERATION = '00000000-0000-4000-8000-000000000002'
  HEAD = 'b' * 40
  BASE = 'c' * 40

  def refreshed_body(directory)
    usage = JSON.parse(empty_usage(directory))
    log = File.join(directory, 'gh.log')
    bind_pull_request(directory, usage)
    _out, err, status = run_hook(hook_env(directory, published_pull(usage), log))
    assert_predicate status, :success?, err
    patched_body(log)
  end

  def saved_record(directory)
    usage = JSON.parse(empty_usage(directory))
    bind_pull_request(directory, usage)
    _out, err, status = run_hook(cursor_env(directory).merge('PATH' => "#{failing_gh(directory)}:#{ENV.fetch('PATH')}"))
    assert_predicate status, :success?, err
    File.read(File.join(directory, "#{SESSION}.jsonl"))
  end

  private

  def published_pull(usage, extra: nil, records: nil)
    block = Shaka::UsageDetailsBlock.markdown('note' => usage['note'], 'records' => records || [usage['record']])
    block = block.sub("</details>\n", "#{extra}\n</details>\n") if extra
    body = "<!-- shaka:begin -->\nA summary.\n\n#{block}\n<!-- shaka:end -->"
    repo = { 'full_name' => 'owner/repo' }
    { 'body' => body, 'head' => { 'sha' => HEAD, 'repo' => repo }, 'base' => { 'sha' => BASE, 'repo' => repo } }
  end

  def bind_pull_request(directory, usage)
    with_cursor(directory) do
      Shaka::CursorUsageRefresh.bind('owner/repo', 42, 'note' => usage['note'], 'records' => [usage['record']])
    end
  end

  def hook_env(directory, pull, log)
    cursor_env(directory).merge('PATH' => "#{bin_dir(directory, pull, log)}:#{ENV.fetch('PATH')}")
  end

  def run_hook(env, **overrides) = Open3.capture3(env, HOOK, stdin_data: JSON.generate(payload.merge(overrides)))

  def patched_body(log)
    calls = File.readlines(log, chomp: true).map { |line| JSON.parse(line) }
    patched = calls.reverse.find { |call| call['argv'].include?('PATCH') }
    assert patched, 'expected the stop hook to update the pull request'
    JSON.parse(patched['stdin'])['body']
  end

  def failing_gh(directory) = write_gh(directory, "#!/bin/sh\nexit 1\n")

  def empty_usage(directory)
    output, error, status = Open3.capture3(cursor_env(directory), COMMAND, 'usage', '--format', 'json',
                                           '--commit', COMMIT, '--contribution', 'implementation')
    assert_predicate status, :success?, error
    output
  end

  def with_cursor(directory)
    keys = %w[CURSOR_CONVERSATION_ID CURSOR_USAGE_DIR]
    previous = keys.to_h { |key| [key, ENV.fetch(key, nil)] }
    ENV['CURSOR_CONVERSATION_ID'] = SESSION
    ENV['CURSOR_USAGE_DIR'] = directory
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def cursor_env(directory)
    { 'CURSOR_CONVERSATION_ID' => SESSION, 'CURSOR_USAGE_DIR' => directory, 'PI_CODING_AGENT' => nil,
      'CODEX_THREAD_ID' => nil, 'CLAUDE_CODE_SESSION_ID' => nil }
  end

  def payload
    { conversation_id: SESSION, generation_id: GENERATION, model: 'cursor-grok-4.6-medium', model_id: 'grok-4.6',
      model_params: [{ id: 'effort', value: 'medium' }, { id: 'fast', value: 'false' }], hook_event_name: 'stop',
      cursor_version: '3.20.21', input_tokens: 100, output_tokens: 20, cache_read_tokens: 40,
      cache_write_tokens: 7, text: 'SENSITIVE-OUTPUT', user_email: 'SENSITIVE@example.com' }
  end

  def bin_dir(directory, pull, log) = write_gh(directory, gh_script(pull, log))

  def write_gh(directory, source)
    bin = File.join(directory, 'bin')
    FileUtils.mkdir_p(bin)
    File.write(File.join(bin, 'gh'), source)
    File.chmod(0o755, File.join(bin, 'gh'))
    bin
  end

  def gh_script(pull, log)
    <<~RUBY
      #!/usr/bin/env ruby
      require 'json'
      raw = STDIN.read
      File.open(#{log.dump}, 'a') { |file| file.puts JSON.generate('argv' => ARGV, 'stdin' => raw) }
      if ARGV.include?('markdown')
        text = JSON.parse(raw).fetch('text')
        tables = text.lines.count { |line| line.match?(/\\A\\s*\\|[\\s|:-]*-{3}[\\s|:-]*\\|\\s*\\z/) }
        puts '<p>Short.</p>' + ('<table></table>' * tables)
      else
        puts ARGV.include?('PATCH') ? JSON.generate(JSON.parse(raw)) : #{JSON.generate(pull).dump}
      end
    RUBY
  end
end

# A description published before the stop hook has no Cursor tokens. The hook writes
# the record after the turn, and that write has to update the description.
class CursorUsageRefreshTest < Minitest::Test
  include CursorUsageRefreshFixture

  def test_stop_hook_fills_the_cursor_usage_row_it_just_wrote
    Dir.mktmpdir do |directory|
      updated = refreshed_body(directory)
      assert_includes updated, '"effort":"medium"'
      assert_includes updated, '"input":"100"'
      refute_includes updated, Shaka::CursorUsage::UNAVAILABLE
    end
  end

  def test_a_failed_refresh_still_saves_the_stop_record
    Dir.mktmpdir do |directory|
      saved = saved_record(directory)
      assert_equal GENERATION, JSON.parse(saved.lines.first)['generation_id']
      refute_match(/SENSITIVE/, saved)
    end
  end

  def test_stop_hook_keeps_a_row_added_after_publication
    Dir.mktmpdir do |directory|
      usage = JSON.parse(empty_usage(directory))
      log = File.join(directory, 'gh.log')
      bind_pull_request(directory, usage)
      _out, err, status = run_hook(hook_env(directory, published_pull(usage, extra: kept_report), log))
      assert_predicate status, :success?, err
      assert_includes patched_body(log), 'kept-source'
    end
  end

  def test_stop_hook_leaves_other_work_off_the_pull_request
    Dir.mktmpdir do |directory|
      usage = JSON.parse(empty_usage(directory))
      remember_other_work(directory)
      log = File.join(directory, 'gh.log')
      bind_pull_request(directory, usage)
      _out, err, status = run_hook(hook_env(directory, published_pull(usage), log))
      assert_predicate status, :success?, err
      refute_includes patched_body(log), 'e' * 40
    end
  end

  def test_a_later_stop_does_not_update_the_pull_request
    Dir.mktmpdir do |directory|
      usage = JSON.parse(empty_usage(directory))
      log = File.join(directory, 'gh.log')
      bind_pull_request(directory, usage)
      env = hook_env(directory, published_pull(usage), log)
      2.times { run_hook(env) }
      patches = File.readlines(log, chomp: true).count { |line| JSON.parse(line)['argv'].include?('PATCH') }
      assert_equal 1, patches
    end
  end

  def test_a_broken_selection_still_saves_the_stop_record
    Dir.mktmpdir { |directory| assert_broken_selection_saved(directory) }
  end

  private

  def assert_broken_selection_saved(directory)
    usage = JSON.parse(empty_usage(directory))
    bind_pull_request(directory, usage)
    break_selection(directory)
    _out, err, status = run_hook(hook_env(directory, published_pull(usage), File.join(directory, 'gh.log')))
    assert_predicate status, :success?, err
    assert_saved(directory)
  end

  def assert_saved(directory)
    saved = File.read(File.join(directory, "#{SESSION}.jsonl"))
    assert_equal GENERATION, JSON.parse(saved.lines.first)['generation_id']
    assert JSON.parse(File.read(File.join(directory, 'pending', "#{SESSION}.json")))['publication']
  end

  def kept_report
    fields = { 'host' => 'claude-code', 'sources' => ['kept-source'], 'responses' => ['kept-response'],
               'contribution' => 'review', 'commits' => ['d' * 40], 'complete' => true,
               'from' => '2026-09-14T12:00:00Z', 'to' => '2026-09-14T13:00:00Z' }
    "#{Shaka::UsageRecords.begin_mark(fields)}\n<!-- usage-columns #{kept_column} -->\n#{Shaka::UsageRecords::END_MARK}"
  end

  def kept_column
    JSON.generate([{ 'label' => 'kept-review', 'provider' => 'anthropic', 'model' => 'claude',
                     'routed' => 'UNKNOWN', 'effort' => 'medium', 'credits' => 'UNKNOWN', 'usd' => 'UNKNOWN',
                     'input' => '1', 'cached_input' => '0', 'output' => '0', 'reasoning_output' => 'UNKNOWN',
                     'cache_writes' => 'UNKNOWN' }])
  end

  def remember_other_work(directory)
    with_cursor(directory) do
      Shaka::CursorUsageRefresh.remember(
        { host: 'cursor', commit: 'e' * 40, contribution: 'review', files: [], turns: [] }, inferred: false
      )
    end
  end

  def break_selection(directory)
    path = File.join(directory, 'pending', "#{SESSION}.json")
    request = JSON.parse(File.read(path))
    request['selections'].first['since_time'] = 1
    File.write(path, "#{JSON.generate(request)}\n")
  end
end

# A live edit and a failed first stop must not be overwritten by the snapshot.
class CursorUsageRefreshCarryTest < Minitest::Test
  include CursorUsageRefreshFixture

  LATER = '00000000-0000-4000-8000-000000000003'

  def test_stop_hook_keeps_an_edited_non_cursor_row
    Dir.mktmpdir do |directory|
      body = edited_body(directory)
      assert_includes body, '"input":"9"'
      refute_includes body, '"input":"7"'
    end
  end

  def test_a_selection_keeps_the_generation_stamped_before_publish
    Dir.mktmpdir do |directory|
      body = stamped_body(directory)
      assert_includes body, '"input":"100"'
      refute_includes body, '"input":"999"'
    end
  end

  def test_a_filled_selection_is_not_kept_for_a_later_description
    Dir.mktmpdir { |directory| assert_filled_selection_dropped(directory) }
  end

  def test_a_retry_counts_the_generation_from_the_failed_stop
    Dir.mktmpdir do |directory|
      body = retried_body(directory)
      assert_includes body, '"input":"100"'
      refute_includes body, '"input":"999"'
    end
  end

  private

  def stamped_body(directory)
    usage = JSON.parse(empty_usage(directory))
    run_hook(hook_env(directory, published_pull(usage), File.join(directory, 'early.log')))
    bind_pull_request(directory, usage)
    patched_after(directory, published_pull(usage), generation_id: LATER, input_tokens: 999)
  end

  def assert_filled_selection_dropped(directory)
    refreshed_body(directory)
    request = JSON.parse(File.read(File.join(directory, 'pending', "#{SESSION}.json")))
    assert_nil request['publication']
    refute_includes Array(request['selections']).map { |item| item['commit'] }, COMMIT
  end

  def edited_body(directory)
    usage = JSON.parse(empty_usage(directory))
    bind_edited(directory, usage)
    patched_after(directory, edited_pull(usage))
  end

  def bind_edited(directory, usage)
    records = [usage['record'], edited_record]
    with_cursor(directory) do
      Shaka::CursorUsageRefresh.bind('owner/repo', 42, 'note' => usage['note'], 'records' => records)
    end
  end

  def edited_pull(usage)
    pull = published_pull(usage, records: [usage['record'], edited_record])
    pull['body'] = pull['body'].sub('"input":"7"', '"input":"9"')
    pull
  end

  def edited_record
    column = CliOpeningCheckFakes::USAGE_COLUMN.merge('label' => 'snapshot-claude', 'input' => '7')
    USAGE_RECORD.merge('host' => 'claude-code', 'columns' => [column])
  end

  def retried_body(directory)
    usage = JSON.parse(empty_usage(directory))
    bind_pull_request(directory, usage)
    fail_once(directory, published_pull(usage))
    patched_after(directory, published_pull(usage), generation_id: LATER, input_tokens: 999)
  end

  def fail_once(directory, pull)
    failed = hook_env(directory, pull, File.join(directory, 'fail.log'))
    failed['PATH'] = "#{failing_gh(directory)}:#{ENV.fetch('PATH')}"
    run_hook(failed)
  end

  def patched_after(directory, pull, **overrides)
    log = File.join(directory, 'gh.log')
    _out, err, status = run_hook(hook_env(directory, pull, log), **overrides)
    assert_predicate status, :success?, err
    patched_body(log)
  end
end

# Description has to record the pull request or the stop hook has nothing to update.
class CursorUsageRefreshDescriptionTest < Minitest::Test
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'The stop hook can fill this Cursor usage row.'
  SESSION = '11111111-1111-4111-8111-111111111111'

  def test_description_records_the_cursor_pull_request
    Dir.mktmpdir { |dir| assert_bound recorded_request(dir) }
  end

  private

  def assert_bound(request)
    assert_equal 1, request.dig('publication', 'number')
    assert_equal 'owner/repo', request.dig('publication', 'repository')
  end

  def recorded_request(dir)
    write_fake_commands(dir)
    assert_equal 'bound', JSON.parse(publish_description(dir))['cursor_usage_refresh']
    JSON.parse(File.read(File.join(dir, 'usage', 'pending', "#{SESSION}.json")))
  end

  def publish_description(dir)
    content = File.join(dir, 'content.json')
    File.write(content, JSON.generate(description_content))
    output, error, status = Open3.capture3(description_env(dir), COMMAND, 'description', 'owner/repo', '1',
                                           '--root', ROOT, '--content-file', content)
    assert_predicate status, :success?, error
    output
  end

  def description_content
    record = USAGE_RECORD.merge('host' => 'cursor', 'columns' => [CliOpeningCheckFakes::USAGE_COLUMN])
    super.merge('usage' => { 'note' => 'Native usage is PARTIAL.', 'records' => [record] })
  end

  def description_env(dir)
    { 'PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'HOME' => dir, 'CURSOR_CONVERSATION_ID' => SESSION,
      'CURSOR_USAGE_DIR' => File.join(dir, 'usage'), 'PI_CODING_AGENT' => nil, 'CODEX_THREAD_ID' => nil,
      'CLAUDE_CODE_SESSION_ID' => nil }
  end
end
