# frozen_string_literal: true

require_relative 'test_helper'

class CliDescriptionPreflightTest < Minitest::Test
  def test_reports_the_input_errors_from_pull_request_1203_together
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'content.json')
      File.write(path, JSON.generate(reconstructed_content))
      _, error, status = run_description(dir, path)

      refute_predicate status, :success?
      assert_diagnostics(error)
      refute_path_exists File.join(dir, 'contacted-github')
    end
  end

  private

  def reconstructed_content
    {
      'identity' => 'Codex',
      'provenance' => { 'task_source' => 'prompt' },
      'verification' => { 'checks' => ['Local tests passed.'] },
      'skills_used' => [{ 'name' => 'shaka' }]
    }
  end

  def run_description(dir, path)
    gh = File.join(dir, 'gh')
    File.write(gh, "#!/bin/sh\ntouch \"$HOME/contacted-github\"\nexit 1\n")
    File.chmod(0o755, gh)
    env = SESSION_ENV_CLEARED.merge('PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'HOME' => dir)
    Open3.capture3(env, *SHAKA_COMMAND, 'description', 'owner/repo', '1', '--content-file', path)
  end

  def assert_diagnostics(error)
    assert_includes error, 'identity'
    assert_includes error, 'task_source is invalid'
    assert_includes error, 'verification check needs a Markdown link or a code span'
    assert_includes error, 'skills_used record fields'
  end
end
