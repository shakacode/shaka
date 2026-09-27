# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require_relative 'cli_opening_check_fakes'
require 'json'
require 'rbconfig'

# Exercises the description command through rendering, model output, and GitHub publication.
class CliOpeningCheckTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = '`shaka merge` now checks the reviewed head.'
  FALLBACK_ROUTES = [
    [{ 'enabled' => false }, 'anthropic/claude'],
    [{ 'enabled' => true, 'prompt_file' => '.agents/missing.md' }, 'anthropic/claude'],
    [{ 'enabled' => true }, 'unlisted/model']
  ].freeze

  def test_description_returns_the_opening_result_after_publishing
    Dir.mktmpdir do |dir|
      output, error, status = run_description(dir)
      assert_predicate status, :success?, error
      assert_equal 'host_check', JSON.parse(output).dig('opening', 'status')
      assert_includes File.read(File.join(dir, 'published.md')), SUMMARY
      refute_path_exists File.join(dir, 'claude-called')
    end
  end

  def test_trusted_setting_allows_a_listed_reviewer
    with_repository('opening_check' => { 'enabled' => true }) do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        output, error, status = run_description(dir, root:, reviewer: 'anthropic/claude')
        assert_predicate status, :success?, error
        assert_equal 'flagged', JSON.parse(output).dig('opening', 'status')
        assert_path_exists File.join(dir, 'claude-called')
      end
    end
  end

  def test_unavailable_or_untrusted_opening_route_publishes_with_host_fallback
    FALLBACK_ROUTES.each do |setting, reviewer|
      with_repository('opening_check' => setting) do |root|
        commit(root)
        Dir.mktmpdir { |dir| assert_host_fallback(dir, root:, reviewer:) }
      end
    end
  end

  private

  def assert_host_fallback(dir, root:, reviewer:)
    output, error, status = run_description(dir, root:, reviewer:)
    assert_predicate status, :success?, error
    assert_equal 'host_check', JSON.parse(output).dig('opening', 'status')
    assert_path_exists File.join(dir, 'published.md')
    refute_path_exists File.join(dir, 'claude-called')
  end

  def run_description(dir, root: ROOT, reviewer: nil)
    write_executable(dir, 'gh', fake_gh)
    write_executable(dir, 'claude', fake_claude)
    content = File.join(dir, 'content.json')
    File.write(content, JSON.generate(description_content))
    options = ['--root', root, '--content-file', content]
    options.push('--ref', 'HEAD', '--opening-reviewer', reviewer) if reviewer
    Open3.capture3({ 'PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'HOME' => dir },
                   COMMAND, 'description', 'owner/repo', '1', *options)
  end

  def commit(root)
    system('git', '-C', root, 'init', '-q', exception: true)
    system('git', '-C', root, 'add', '.', exception: true)
    system('git', '-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
           'commit', '-qm', 'trusted', exception: true)
  end

  def description_content
    provenance = %w[task_source initial_prompt workflow_version requested_model requested_effort
                    recommended_model recommended_effort active_model active_effort].to_h { |key| [key, 'UNKNOWN'] }
    provenance['task_source'] = 'issue'
    provenance['initial_prompt'] = 'EXCLUDED'
    { 'identity' => { 'agent' => 'Codex' }, 'summary' => SUMMARY, 'deployment' => 'none',
      'table' => { 'columns' => %w[Check Result], 'rows' => [%w[validate pass]] },
      'provenance' => provenance,
      'details' => [{ 'summary' => 'Usage', 'body' => "| Metric | Value |\n| --- | --- |\n| Total | 1 |" }] }
  end

  def write_executable(dir, name, source)
    path = File.join(dir, name)
    File.write(path, "#!#{RbConfig.ruby}\n#{source}")
    File.chmod(0o755, path)
  end
end
