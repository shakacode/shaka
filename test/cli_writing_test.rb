# frozen_string_literal: true

require_relative 'test_helper'

# The advisory prints beside the publication and never decides whether it happens.
class CliWritingTest < Minitest::Test
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def test_walkthrough_advisory_prints_the_style_signals_and_does_not_block
    Dir.mktmpdir do |dir|
      sentinel = File.join(dir, 'called')
      stub_gh(dir, sentinel)
      error = publish(dir, 'Adds a duplication check.')
      assert_includes error, 'walkthrough writing advisory, not enforced'
      assert_includes error, 'reading grade'
      assert_includes error, 'diff-shaped'
      assert File.exist?(sentinel), 'the advisory must not replace the publication attempt'
    end
  end

  private

  def stub_gh(dir, sentinel)
    File.write(File.join(dir, 'gh'), "#!/bin/sh\ntouch #{sentinel}\nexit 1\n")
    File.chmod(0o755, File.join(dir, 'gh'))
  end

  def publish(dir, summary)
    body = File.join(dir, 'walkthrough.md')
    File.write(body, "#{summary}\n")
    _out, error, status = Open3.capture3({ 'PATH' => "#{dir}:#{ENV.fetch('PATH')}" }, COMMAND, 'walkthrough',
                                         'owner/repo', '1', '--head', 'a' * 40, '--body-file', body)
    refute status.success?, 'the stub gh must still fail the publication'
    error
  end
end
