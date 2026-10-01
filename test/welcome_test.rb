# frozen_string_literal: true

require_relative 'test_helper'

class WelcomeTest < Minitest::Test
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def test_no_arguments_welcomes_a_new_user_without_contacting_github
    Dir.mktmpdir do |directory|
      sentinel = File.join(directory, 'contacted')
      output, error, status = welcome_without_github(directory, sentinel)

      assert_predicate status, :success?, error
      assert_empty error
      assert_welcome_has_next_steps(output)
      refute_path_exists sentinel
    end
  end

  private

  def assert_welcome_has_next_steps(output)
    assert_includes output, 'tested, reviewed PR'
    assert_includes output, 'shaka doctor'
    assert_includes output, 'Configure this repository'
    assert_includes output, 'https://github.com/OWNER/REPO/pull/123'
  end

  def welcome_without_github(directory, sentinel)
    File.write(File.join(directory, 'gh'), "#!/bin/sh\ntouch #{sentinel}\nexit 1\n")
    File.chmod(0o755, File.join(directory, 'gh'))
    Open3.capture3({ 'PATH' => "#{directory}:#{ENV.fetch('PATH')}" }, COMMAND, chdir: directory)
  end
end
