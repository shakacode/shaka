# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/call_log'
require 'shaka/help'

class HelpTest < Minitest::Test
  COMMAND = SHAKA_COMMAND
  REPO_ROOT = File.expand_path('..', __dir__)

  def test_help_lists_topics_offline_with_default_env_and_writes_no_notice_state
    with_isolated_env do |dir, home, sentinel|
      output, error, status = run_help(dir, home, call_log: nil)

      assert_predicate status, :success?, error
      assert_empty error
      %w[setup tasks reviews settings].each { |topic| assert_includes output, topic }
      assert_includes output, 'shaka COMMAND --help'
      refute_path_exists sentinel
      assert_only_call_log_written(home)
    end
  end

  def test_help_writes_nothing_to_home_when_call_log_is_off
    with_isolated_env do |dir, home, sentinel|
      _output, error, status = run_help(dir, home, call_log: 'off')

      assert_predicate status, :success?, error
      assert_empty error
      refute_path_exists sentinel
      assert_empty Dir.children(home)
    end
  end

  def test_help_topic_shows_prompts_url_and_local_guide_with_anchor
    with_isolated_env do |dir, home, sentinel|
      output, error, status = run_help(dir, home, 'merging')

      assert_predicate status, :success?, error
      assert_empty error
      assert_includes output, 'working-with-shaka.md#choose-a-merge-policy'
      assert_includes output, "Local guide: #{File.join(REPO_ROOT, 'docs/working-with-shaka.md')}#choose-a-merge-policy"
      refute_path_exists sentinel
    end
  end

  def test_help_resolves_topic_aliases_case_insensitively
    output, error, status = Open3.capture3(*COMMAND, 'help', 'CONFIG')

    assert_predicate status, :success?, error
    assert_empty error
    assert_includes output, 'settings-guide.md'
  end

  def test_help_json_returns_all_topics
    all_output, all_error, all_status = Open3.capture3(*COMMAND, 'help', '--json')
    assert_predicate all_status, :success?, all_error
    refute_empty JSON.parse(all_output).fetch('topics')
  end

  def test_help_json_accepts_flag_before_or_after_topic_under_posixly_correct
    orders = [%w[--json merging], %w[merging --json]]
    [nil, '1'].each do |posix|
      orders.each do |args|
        output, error, status = Open3.capture3({ 'POSIXLY_CORRECT' => posix }, *COMMAND, 'help', *args)
        assert_predicate status, :success?, error
        topic = JSON.parse(output)
        assert_equal %w[merging choose-a-merge-policy], [topic['id'], topic['anchor']]
      end
    end
  end

  def test_help_json_rejects_unknown_topic_and_extra_arguments
    _out, bad_error, bad_status = Open3.capture3(*COMMAND, 'help', '--json', 'doctor')
    refute_predicate bad_status, :success?
    assert_includes bad_error, 'doctor'

    _out, extra_error, extra_status = Open3.capture3(*COMMAND, 'help', '--json', 'setup', 'extra')
    refute_predicate extra_status, :success?
    assert_includes extra_error, 'at most one'
  end

  private

  def with_isolated_env
    Dir.mktmpdir do |dir|
      home = FileUtils.mkdir_p(File.join(dir, 'home')).first
      sentinel = File.join(dir, 'contacted')
      %w[gh git].each { |tool| stub_tool(File.join(dir, tool), sentinel) }
      yield dir, home, sentinel
    end
  end

  def stub_tool(path, sentinel)
    File.write(path, "#!/bin/sh\ntouch #{sentinel}\nexit 1\n")
    File.chmod(0o755, path)
  end

  def run_help(dir, home, *, call_log: 'off')
    env = { 'HOME' => home, 'PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'SHAKA_NOTICES' => nil,
            'SHAKA_CALL_LOG' => call_log }
    Open3.capture3(env, *COMMAND, 'help', *, chdir: dir)
  end

  def assert_only_call_log_written(home)
    state_dir = File.join(home, '.local/state/shaka')
    assert_equal ['calls.jsonl'], Dir.children(state_dir)
    record = JSON.parse(File.readlines(File.join(state_dir, 'calls.jsonl')).last)
    assert_equal 'help', record.fetch('command')
  end
end

class HelpPointersTest < Minitest::Test
  COMMAND = SHAKA_COMMAND

  def test_help_points_cli_commands_and_operations_to_their_help_flag
    assert_command_pointer('shaka doctor --help', 'Related topic: shaka help setup', 'doctor')
    assert_command_pointer('shaka doctor --help', 'Related topic: shaka help setup', 'Doctor')
    assert_command_pointer('shaka doctor --help', 'Related topic: shaka help setup', 'doctor', '--help')
    assert_command_pointer('shaka seam <operation> --help', 'Operations: check, init', 'seam')
    assert_command_pointer('shaka seam check --help', 'Related topic: shaka help setup', 'seam', 'check')
    assert_command_pointer('shaka seam check --help', 'Related topic: shaka help setup', 'seam', 'check', '--help')
    assert_command_pointer('shaka pr watch --help', nil, 'pr', 'watch')
    assert_command_pointer('shaka walkthrough --help', 'Walkthrough input:', 'walkthrough')
  end

  def test_help_usage_banner_and_help_flags
    banner = "Usage: shaka help [TOPIC] [--json]\n       shaka help COMMAND [OPERATION]"
    assert_command_pointer(banner, nil, 'help')
    assert_command_pointer(banner, nil, '--help')
    assert_command_pointer(banner, nil, '--json', '--help')
  end

  def test_advertised_help_targets_exit_zero_offline
    Dir.mktmpdir do |dir|
      home = FileUtils.mkdir_p(File.join(dir, 'home')).first
      sentinel = File.join(dir, 'contacted')
      %w[gh git].each { |tool| stub_tool(File.join(dir, tool), sentinel) }
      env = { 'HOME' => home, 'PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'SHAKA_NOTICES' => nil,
              'SHAKA_CALL_LOG' => 'off' }
      [%w[doctor], %w[merge], %w[evidence run], %w[seam check]].each { |words| assert_cli_help(env, dir, words) }
      refute_path_exists sentinel
    end
  end

  def test_unknown_topic_or_invalid_operation_exits_nonzero
    [['not-a-real-topic'], %w[seam nonexistent]].each do |args|
      _output, error, status = Open3.capture3(*COMMAND, 'help', *args)

      refute_predicate status, :success?
      assert_includes error, args.join(' ')
      assert_includes error, 'shaka help'
    end
  end

  private

  def assert_command_pointer(expected_cmd, expected_extra, *)
    output, error, status = Open3.capture3(*COMMAND, 'help', *)
    assert_predicate status, :success?, error
    assert_includes output, expected_cmd
    assert_includes output, expected_extra if expected_extra
  end

  def assert_cli_help(env, dir, words)
    output, error, status = Open3.capture3(env, *COMMAND, *words, '--help', chdir: dir)
    assert_predicate status, :success?, error
    assert_includes output, 'Usage:'
  end

  def stub_tool(path, sentinel)
    File.write(path, "#!/bin/sh\ntouch #{sentinel}\nexit 1\n")
    File.chmod(0o755, path)
  end
end

class HelpCatalogTest < Minitest::Test
  REPO_ROOT = File.expand_path('..', __dir__)

  def test_missing_local_docs_omits_local_guide_line
    Dir.mktmpdir do |empty_root|
      catalog = Shaka::Help::Catalog.load(source_root: empty_root)
      topic = catalog.find('setup')
      assert_nil topic['local_doc']
      refute_includes Shaka::Help::Formatter.topic(topic), 'Local guide:'
    end
  end

  def test_topic_keys_are_unique_do_not_collide_with_cli_commands_and_docs_and_anchors_exist
    catalog = Shaka::Help::Catalog.load
    keys = catalog.topics.flat_map { |topic| [topic.fetch('id'), *topic.fetch('aliases')] }
    assert_equal keys.uniq, keys, 'Help topic IDs and aliases must be unique'
    assert_empty keys & Shaka::CallLog::COMMANDS, 'Help topic keys must not collide with CLI commands'
    catalog.topics.each { |topic| assert_doc_and_anchor(topic) }
  end

  def test_every_related_topic_pointer_is_reachable_and_valid
    catalog = Shaka::Help::Catalog.load
    topic_ids = catalog.topics.map { it.fetch('id') }
    Shaka::Help::Formatter::RELATED_TOPICS.each do |command, topic_id|
      assert_includes Shaka::CallLog::COMMANDS, command
      assert_includes topic_ids, topic_id
      output, = capture_io { assert_equal 0, Shaka::Help.run([command]) }
      assert_includes output, "Related topic: shaka help #{topic_id}"
    end
  end

  def test_every_dispatched_command_and_operation_prints_pointer_offline
    bare = [[]]
    Shaka::CallLog::COMMANDS.each do |name|
      next if name == 'help'

      ops = Shaka::CallLog::OPERATIONS.fetch(name, [])
      (bare + ops.zip).each do |words|
        output, = capture_io { assert_equal 0, Shaka::Help.run([name, *words]) }
        target = words.empty? && !ops.empty? ? "#{name} <operation>" : [name, *words].join(' ')
        assert_includes output, "shaka #{target} --help"
      end
    end
  end

  private

  def assert_doc_and_anchor(topic)
    path = File.join(REPO_ROOT, topic.fetch('doc'))
    assert_path_exists path
    return unless topic['anchor']

    assert_includes doc_anchors(path), topic['anchor'], "Missing anchor ##{topic['anchor']} in #{topic['doc']}"
  end

  def doc_anchors(path)
    text = File.read(path, encoding: 'UTF-8')
    headings = text.scan(/^ {0,3}\#{1,6}[ \t]+(.+?)[ \t]*$/).flatten.map do |heading|
      heading.gsub(/<[^>]*>/, '').gsub(/\[([^\]]*)\]\([^)]*\)/, '\\1')
             .downcase.strip.gsub(/[^\p{Word}\- ]/, '').tr(' ', '-')
    end
    headings + text.scan(/<a\s+(?:id|name)\s*=\s*["']([^"']+)["']/).flatten
  end
end
