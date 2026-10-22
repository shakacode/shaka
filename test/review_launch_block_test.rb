# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'review_prompt_file_test'

# A cloud machine without reviewer CLIs or keys must learn from one run that no reviewer can start.
class ReviewLaunchBlockTest < Minitest::Test
  include ReviewPromptFileFixture

  AGENTS = [{ 'provider' => 'openai', 'model_family' => 'codex' },
            { 'provider' => 'deepseek', 'model_family' => 'openrouter',
              'model' => 'deepseek/deepseek-v4.1-flash', 'effort' => 'low' }].freeze

  def test_a_missing_executable_reports_that_no_configured_reviewer_can_start
    with_bare_machine do |head|
      result = launch('openai/codex')
      assert_equal 'executable_missing', result.fetch('failure_stage')
      assert_blocked(result, head)
    end
  end

  def test_missing_credentials_report_that_no_configured_reviewer_can_start
    with_bare_machine do |head|
      result = launch('deepseek/openrouter')
      assert_equal 'credentials_missing', result.fetch('failure_stage')
      assert_blocked(result, head)
    end
  end

  def test_another_configured_reviewer_that_can_start_keeps_the_list_open
    with_bare_machine do
      result = launch('openai/codex', key: 'test-key')
      assert_equal 'executable_missing', result.fetch('failure_stage')
      refute result.key?('review_blocked')
    end
  end

  private

  def assert_blocked(result, head)
    refute result.fetch('attempted')
    assert_equal 'no_reviewer_can_launch', result.fetch('review_blocked')
    assert_includes result.fetch('guidance'), "shaka review check --head #{head} --not-run-reason"
  end

  def launch(reviewer, key: nil)
    root, base, head, bin = @machine
    output, = Open3.capture3({ 'PATH' => bin, 'OPENROUTER_API_KEY' => key },
                             COMMAND, 'review', 'run', '--root', root, '--base', base, '--head', head,
                             '--reviewer', reviewer, '--criteria-ref', base)
    JSON.parse(output)
  end

  # Only Ruby and Git are on PATH: no reviewer CLI and, unless a test supplies one, no API key.
  def with_bare_machine
    with_repository({ 'local_review_agents' => AGENTS }) do |root, base, head, bin|
      File.unlink(File.join(bin, 'codex'))
      File.symlink(RbConfig.ruby, File.join(bin, 'ruby'))
      File.symlink(TEST_GIT, File.join(bin, 'git'))
      @machine = [root, base, head, bin]
      yield head
    end
  end
end
