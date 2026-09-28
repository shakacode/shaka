# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require_relative 'cli_opening_check_fakes'
require 'json'

class CliDescriptionDecisionsTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Decisions stay with the label.'

  def test_description_applies_awaiting_answer_when_decisions_are_present
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        output, error, status = run_description(dir, root:, ref: true)

        assert_predicate status, :success?, error
        assert_includes File.read(File.join(dir, 'published.md')), '## Decisions for the maintainer'
        assert_equal 'awaiting-answer', File.read(File.join(dir, 'labeled')).strip
        assert_equal ['awaiting-answer'], JSON.parse(output).dig('attention', 'labels')
      end
    end
  end

  def test_description_refuses_decisions_on_a_closed_pull_request_before_writing
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        _output, error, status = run_description(dir, root:, ref: true, env: { 'PR_STATE' => 'CLOSED' })

        refute_predicate status, :success?
        assert_includes error, 'not open'
        refute_path_exists File.join(dir, 'published.md')
        refute_path_exists File.join(dir, 'labeled')
      end
    end
  end

  def test_description_refuses_decisions_while_awaiting_merge_approval
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        env = { 'PR_LABEL' => 'awaiting-merge-approval' }
        _output, error, status = run_description(dir, root:, ref: true, env:)

        refute_predicate status, :success?
        assert_includes error, 'awaiting-merge-approval'
        refute_path_exists File.join(dir, 'published.md')
      end
    end
  end

  def test_description_does_not_label_when_a_decision_is_blank
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        _output, error, status = run_description(dir, root:, ref: true, decisions: ['  '])

        refute_predicate status, :success?
        assert_includes error, 'decision'
        refute_path_exists File.join(dir, 'published.md')
        refute_path_exists File.join(dir, 'labeled')
      end
    end
  end

  def test_description_without_decisions_does_not_touch_labels
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        _output, error, status = run_description(dir, root:, ref: true, decisions: false)

        assert_predicate status, :success?, error
        log = File.read(File.join(dir, 'gh-log'))
        refute_includes log, 'labels'
        refute_path_exists File.join(dir, 'labeled')
      end
    end
  end

  private

  def run_description(dir, root:, ref:, env: {}, decisions: true)
    @decisions = decisions == true ? ['Which base?'] : decisions
    write_fake_commands(dir)
    content = File.join(dir, 'content.json')
    File.write(content, JSON.generate(description_content))
    options = ['--root', root, '--content-file', content, '--ref', fixture_ref(root)]
    options.delete('--ref') unless ref
    Open3.capture3({ 'PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'HOME' => dir }.merge(env),
                   COMMAND, 'description', 'owner/repo', '1', *options)
  end

  def description_content
    content = super
    content['decisions'] = @decisions if @decisions
    content
  end

  def fake_gh = DESCRIPTION_GH
end

DESCRIPTION_GH = <<~'RUBY'
  require 'json'
  raw = STDIN.read
  request = raw.empty? ? {} : JSON.parse(raw)
  File.open(File.join(ENV.fetch('HOME'), 'gh-log'), 'a') { |file| file.puts ARGV.inspect }
  path = ARGV[1].to_s
  case path
  when 'repos/owner/repo/pulls/1'
    if ARGV.include?('PATCH')
      File.write(File.join(ENV.fetch('HOME'), 'published.md'), request.fetch('body'))
      puts JSON.generate(request)
    else
      puts JSON.generate('body' => '', 'head' => { 'repo' => { 'full_name' => 'owner/repo' } },
                         'base' => { 'repo' => { 'full_name' => 'owner/repo' } })
    end
  when 'markdown' then puts JSON.generate('<table></table>' * 10)
  when 'graphql'
    state = ENV.fetch('PR_STATE', 'OPEN')
    puts JSON.generate('data' => { 'repository' => { 'pullRequest' => { 'state' => state } } })
  when %r{issues/1/labels\?}
    name = ENV['PR_LABEL'].to_s
    puts JSON.generate(name.empty? ? [] : [{ 'name' => name }])
  when %r{issues/1/labels\z}
    File.write(File.join(ENV.fetch('HOME'), 'labeled'), request.fetch('labels').join(','))
    puts JSON.generate([{ 'name' => 'awaiting-answer' }])
  when 'repos/owner/repo/labels/awaiting-answer'
    puts JSON.generate('name' => 'awaiting-answer')
  else
    abort "unexpected gh request: #{ARGV.inspect} #{raw}"
  end
RUBY
