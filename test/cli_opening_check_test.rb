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
        output, error, status = run_description(dir, root:, reviewer: 'anthropic/claude', model: 'claude-haiku')
        assert_predicate status, :success?, error
        assert_equal 'flagged', JSON.parse(output).dig('opening', 'status')
        assert_path_exists File.join(dir, 'claude-called')
        assert_includes JSON.parse(File.read(File.join(dir, 'claude-args.json'))), 'claude-haiku'
      end
    end
  end

  def test_trusted_prompt_reaches_external_model
    with_trusted_prompt do |root|
      Dir.mktmpdir do |dir|
        output, error, status = run_description(dir, root:, reviewer: 'anthropic/claude')
        assert_predicate status, :success?, error
        assert_equal 'flagged', JSON.parse(output).dig('opening', 'status')
        assert_includes File.read(File.join(dir, 'opening-prompt.txt')), 'Name the reader-facing subject.'
      end
    end
  end

  def test_trusted_prompt_reaches_host_fallback
    with_trusted_prompt do |root|
      Dir.mktmpdir do |dir|
        output, error, status = run_description(dir, root:, reviewer: 'unlisted/model')
        assert_predicate status, :success?, error
        assert_includes JSON.parse(output).dig('opening', 'prompt'), 'Name the reader-facing subject.'
      end
    end
  end

  def test_trusted_prompt_reaches_default_host_model
    with_trusted_prompt do |root|
      Dir.mktmpdir do |dir|
        output, error, status = run_description(dir, root:, ref: true)
        assert_predicate status, :success?, error
        assert_includes JSON.parse(output).dig('opening', 'prompt'), 'Name the reader-facing subject.'
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

  def with_trusted_prompt
    with_repository('opening_check' => { 'enabled' => true, 'prompt_file' => '.agents/opening.md' }) do |root|
      File.write(File.join(root, '.agents/opening.md'), 'Name the reader-facing subject.')
      commit(root)
      yield root
    end
  end

  def assert_host_fallback(dir, root:, reviewer:)
    output, error, status = run_description(dir, root:, reviewer:)
    assert_predicate status, :success?, error
    assert_equal 'host_check', JSON.parse(output).dig('opening', 'status')
    assert_path_exists File.join(dir, 'published.md')
    refute_path_exists File.join(dir, 'claude-called')
  end
end
