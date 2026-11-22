# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
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
      assert_includes output, 'shaka --help'
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

  def test_help_resolves_topic_aliases_case_insensitively_and_accepts_trailing_help
    [%w[CONFIG], %w[merging --help]].each do |args|
      output, error, status = Open3.capture3(*COMMAND, 'help', *args)

      assert_predicate status, :success?, error
      assert_empty error
      assert_includes output, 'Guide: https://github.com/shakacode/shaka/blob/main/docs/'
    end
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

  def test_help_usage_and_errors
    [%w[help], %w[--help], %w[--json --help]].each do |args|
      output, error, status = Open3.capture3(*COMMAND, 'help', *args)
      assert_predicate status, :success?, error
      assert_includes output, 'Usage: shaka help [TOPIC] [--json]'
    end

    [%w[not-a-real-topic], %w[--json doctor], %w[--json setup extra], %w[setup extra]].each do |args|
      _output, error, status = Open3.capture3(*COMMAND, 'help', *args)
      refute_predicate status, :success?
      assert_includes error, 'shaka help'
    end
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

  def test_corrupt_or_missing_catalog_raises_shaka_error
    Dir.mktmpdir do |dir|
      syntax = File.join(dir, 'syntax.yml')
      shape = File.join(dir, 'shape.yml')
      File.write(syntax, ":\n  - [unterminated\n")
      File.write(shape, "groups: []\ntopics:\n")
      [syntax, shape, File.join(dir, 'missing.yml')].each do |path|
        assert_raises(Shaka::Error) { Shaka::Help::Catalog.load(path:) }
      end
    end
  end

  def test_topic_keys_are_unique_and_docs_and_anchors_exist
    catalog = Shaka::Help::Catalog.load
    keys = catalog.topics.flat_map { |topic| [topic.fetch('id'), *topic.fetch('aliases')] }
    assert_equal keys.uniq, keys, 'Help topic IDs and aliases must be unique'
    catalog.topics.each { |topic| assert_doc_and_anchor(topic) }
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
