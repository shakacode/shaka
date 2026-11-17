# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/walkthrough/history'
require 'shaka/publication/publication'

# The ready checkpoint finds a walkthrough by its shape, so the command refuses any other body before GitHub.
class CliWalkthroughBodyTest < Minitest::Test
  COMMAND = SHAKA_COMMAND
  HEAD = 'c' * 40

  def test_walkthrough_help_example_is_a_recognized_body
    output, error, status = Open3.capture3(*COMMAND, 'walkthrough', '--help')
    assert_predicate status, :success?, error
    example = output[/^ {4}🤖.*?This is a COMMENT, not an approval\._$/m]
    refute_nil example, output
    body = example.gsub(/^ {4}/, '').gsub('HEAD_SHA', HEAD)
    assert_nil Shaka::WalkthroughText.verify_recognizable!(body, HEAD)
    refute_includes Open3.capture3(*COMMAND, 'merge', '--help').first, 'Walkthrough input:'
  end

  # --content-file goes through the same gate, so what the renderer writes has to pass it.
  def test_rendered_content_is_a_recognized_body
    summary = "Read [the check](https://github.com/o/r/blob/#{HEAD}/a.rb).\n\n```\n# Code Walkthrough\n```"
    content = { 'identity' => { 'agent' => 'Codex', 'provider' => 'OpenAI', 'model' => 'm', 'effort' => 'e' },
                'summary' => summary, 'head' => HEAD,
                'sections' => [{ 'heading' => 'Risk', 'body' => 'Low.' }],
                'details' => [{ 'summary' => 'Validation', 'body' => 'validate passed.' }] }
    assert_nil Shaka::WalkthroughText.verify_recognizable!(Shaka::Publication.walkthrough(content, 'o/r'), HEAD)
  end

  def test_plain_markdown_walkthrough_file_is_refused_before_github
    Dir.mktmpdir do |dir|
      sentinel = File.join(dir, 'called')
      File.write(File.join(dir, 'gh'), "#!/bin/sh\ntouch #{sentinel}\nexit 1\n")
      File.chmod(0o755, File.join(dir, 'gh'))
      _output, error, status = publish(dir, "# Notes\n\nThe change adds a check.\n")
      refute_predicate status, :success?
      assert_includes error, '--content-file'
      refute_path_exists sentinel, 'the walkthrough reached GitHub with a body the checkpoint would not recognize'
    end
  end

  def publish(dir, body)
    path = File.join(dir, 'walkthrough.md')
    File.write(path, body)
    Open3.capture3({ 'PATH' => "#{dir}:#{ENV.fetch('PATH')}" }, *COMMAND, 'walkthrough', 'owner/repo', '1',
                   '--head', HEAD, '--body-file', path)
  end
end
