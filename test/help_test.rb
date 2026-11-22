# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/call_log'
require 'shaka/subcommands'

class HelpTest < Minitest::Test
  COMMAND = SHAKA_COMMAND
  REPO_ROOT = File.expand_path('..', __dir__)

  def test_help_lists_topics_and_prompts_offline_without_contacting_github
    without_github do |directory, sentinel|
      output, error, status = run_help(directory)

      assert_predicate status, :success?, error
      assert_empty error
      %w[setup tasks reviews settings].each { |topic| assert_includes output, topic }
      assert_includes output, 'shaka help TOPIC'
      refute_path_exists sentinel
    end
  end

  def test_help_topic_shows_prompts_url_and_local_guide_with_anchor
    without_github do |directory, sentinel|
      output, error, status = run_help(directory, 'merging')

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
    output, error, status = Open3.capture3(*COMMAND, 'help', '--json')

    assert_predicate status, :success?, error
    data = JSON.parse(output)
    assert_kind_of Array, data['groups']
    refute_empty data['topics']
  end

  def test_help_json_returns_one_topic
    output, error, status = Open3.capture3(*COMMAND, 'help', '--json', 'merging')

    assert_predicate status, :success?, error
    topic = JSON.parse(output)
    assert_equal 'merging', topic['id']
    assert_equal File.join(REPO_ROOT, 'docs/working-with-shaka.md'), topic['local_doc']
    assert_equal 'choose-a-merge-policy', topic['anchor']
  end

  def test_help_json_rejects_unknown_topic_and_extra_arguments
    _out, bad_error, bad_status = Open3.capture3(*COMMAND, 'help', '--json', 'doctor')
    refute_predicate bad_status, :success?
    assert_includes bad_error, 'doctor'

    _out, extra_error, extra_status = Open3.capture3(*COMMAND, 'help', '--json', 'setup', 'extra')
    refute_predicate extra_status, :success?
    assert_includes extra_error, 'at most one'
  end

  def test_help_forwards_cli_subcommands_trailing_help_and_operations
    assert_command_help('Usage: shaka doctor', 'doctor')
    assert_command_help('Usage: shaka doctor', 'doctor', '--help')
    assert_command_help('shaka seam', 'seam', 'check')
    assert_command_help('shaka pr watch', 'pr', 'watch')
    assert_command_help('Usage: shaka help', 'help')
  end

  def test_help_explains_top_level_pr_commands_including_walkthrough
    output, error, status = Open3.capture3(*COMMAND, 'help', 'walkthrough')
    assert_predicate status, :success?, error
    assert_includes output, 'shaka walkthrough OWNER/REPO NUMBER'
    assert_includes output, 'Walkthrough input:'

    merge_output, merge_error, merge_status = Open3.capture3(*COMMAND, 'help', 'merge')
    assert_predicate merge_status, :success?, merge_error
    assert_includes merge_output, 'shaka merge OWNER/REPO NUMBER'
    assert_includes merge_output, 'See also: shaka help merging'
  end

  def test_unknown_topic_invalid_operation_and_command_flags_exit_nonzero
    [['not-a-real-topic'], %w[seam nonexistent], %w[doctor --root /tmp]].each do |args|
      _output, error, status = Open3.capture3(*COMMAND, 'help', *args)

      refute_predicate status, :success?
      assert_includes error, args.join(' ')
      assert_includes error, 'shaka help'
    end
  end

  private

  def assert_command_help(expected, *)
    output, error, status = Open3.capture3(*COMMAND, 'help', *)
    assert_predicate status, :success?, error
    assert_includes output, expected
  end

  def without_github
    Dir.mktmpdir do |directory|
      sentinel = File.join(directory, 'contacted')
      File.write(File.join(directory, 'gh'), "#!/bin/sh\ntouch #{sentinel}\nexit 1\n")
      File.chmod(0o755, File.join(directory, 'gh'))
      yield directory, sentinel
    end
  end

  def run_help(directory, *)
    Open3.capture3({ 'PATH' => "#{directory}:#{ENV.fetch('PATH')}" }, *COMMAND, 'help', *, chdir: directory)
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

  def test_pr_commands_and_related_topics_match_live_tables
    all_commands = (Shaka::Help::PR_COMMANDS + Shaka::Subcommands::TABLE.keys).sort
    assert_equal Shaka::CallLog::COMMANDS, all_commands

    catalog = Shaka::Help::Catalog.load
    topic_ids = catalog.topics.map { it.fetch('id') }
    Shaka::Help::Formatter::RELATED_TOPICS.each do |command, topic_id|
      assert_includes Shaka::CallLog::COMMANDS, command
      assert_includes topic_ids, topic_id
    end
  end

  def test_every_dispatched_subcommand_help_is_read_only_and_offline
    with_isolated_env do |home, sentinel|
      Shaka::Subcommands::TABLE.each do |name, entry|
        invocations = entry.operations.empty? ? [[]] : entry.operations.zip
        invocations.each { |words| assert_subcommand_help_offline(name, words, home, sentinel) }
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

  def with_isolated_env
    Dir.mktmpdir do |dir|
      home = File.join(dir, 'home')
      FileUtils.mkdir_p(home)
      sentinel = File.join(dir, 'contacted')
      File.write(File.join(dir, 'gh'), "#!/bin/sh\ntouch #{sentinel}\nexit 1\n")
      File.chmod(0o755, File.join(dir, 'gh'))
      with_env('HOME' => home, 'PATH' => "#{dir}:#{ENV.fetch('PATH')}") { yield home, sentinel }
    end
  end

  def with_env(overrides)
    saved = overrides.keys.to_h { |key| [key, ENV.fetch(key, nil)] }
    overrides.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def assert_subcommand_help_offline(name, words, home, sentinel)
    status = nil
    output, = capture_io { status = Shaka::Help.run([name, *words]) }
    assert_equal 0, status, "shaka help #{[name, *words].join(' ')} failed"
    assert_includes output, "shaka #{name}"
    refute_path_exists sentinel
    assert_empty Dir.children(home)
  end
end
