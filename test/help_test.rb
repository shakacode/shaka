# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/call_log'
require 'shaka/help'

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

  def test_help_topic_shows_prompts_url_and_local_guide_path
    without_github do |directory, sentinel|
      output, error, status = run_help(directory, 'settings')

      assert_predicate status, :success?, error
      assert_empty error
      assert_includes output, 'settings-guide.md'
      assert_includes output, "Local guide: #{File.join(REPO_ROOT, 'docs/settings-guide.md')}"
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
    output, error, status = Open3.capture3(*COMMAND, 'help', '--json', 'setup')

    assert_predicate status, :success?, error
    topic = JSON.parse(output)
    assert_equal 'setup', topic['id']
    assert_equal File.join(REPO_ROOT, 'docs/getting-started.md'), topic['local_doc']
  end

  def test_help_json_rejects_unknown_topic_and_extra_arguments
    _out, bad_error, bad_status = Open3.capture3(*COMMAND, 'help', '--json', 'doctor')
    refute_predicate bad_status, :success?
    assert_includes bad_error, 'doctor'

    _out, extra_error, extra_status = Open3.capture3(*COMMAND, 'help', '--json', 'setup', 'extra')
    refute_predicate extra_status, :success?
    assert_includes extra_error, 'at most one'
  end

  def test_help_forwards_cli_subcommands_and_operations
    assert_command_help('Usage: shaka doctor', 'doctor')
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

  def test_unknown_topic_or_invalid_subcommand_operation_exits_nonzero
    [['not-a-real-topic'], %w[seam nonexistent]].each do |args|
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

  def test_topic_keys_are_unique_do_not_collide_with_cli_commands_and_docs_exist
    catalog = Shaka::Help::Catalog.load
    keys = catalog.topics.flat_map { |topic| [topic.fetch('id'), *topic.fetch('aliases')] }
    assert_equal keys.uniq, keys, 'Help topic IDs and aliases must be unique'
    assert_empty keys & Shaka::CallLog::COMMANDS, 'Help topic keys must not collide with CLI commands'
    catalog.topics.each do |topic|
      assert_path_exists File.join(REPO_ROOT, topic.fetch('doc'))
    end
  end
end
