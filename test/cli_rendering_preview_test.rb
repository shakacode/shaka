# frozen_string_literal: true

require_relative 'cli_description_decisions_test'
require 'shaka/publication/rendering_preview'

# Exercises the documented CLI option through publication, rather than yielding literal renderer text.
class CliRenderingPreviewTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes

  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'The reviewed rendering appears on its own PR.'

  def test_description_publishes_current_head_preview_through_the_cli
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |directory|
        _out, err, status = publish_preview(directory, root)
        assert_predicate status, :success?, err
        assert_preview(File.read(File.join(directory, 'published.md')))
      end
    end
  end

  private

  def assert_preview(body)
    head = fixture_ref(ROOT)
    assert Shaka::RenderingPreview.current?(body, head)
    assert_includes body, '## Shaka metrics'
    assert_includes body, '<summary>Companion skill results</summary>'
    assert_includes body, "**Commit:** `#{head}`\n"
    assert_includes body, "**Commit:** `#{'b' * 40}` · stale"
  end

  def publish_preview(directory, root)
    write_fake_commands(directory)
    path = File.join(directory, 'content.json')
    File.write(path, JSON.generate(preview_content))
    args = ['description', 'shakacode/shaka', '1', '--root', root, '--ref', fixture_ref(root),
            '--content-file', path, '--rendering-preview-root', ROOT]
    env = { 'PATH' => "#{directory}:#{ENV.fetch('PATH')}", 'HOME' => directory, 'PREVIEW_HEAD' => fixture_ref(ROOT) }
    Open3.capture3(env, *SHAKA_COMMAND, *args)
  end

  def preview_content
    skill = { 'name' => 'verify-flagship', 'source' => 'pstack', 'revision' => 'v1', 'phase' => 'verification',
              'contribution' => 'Verified the served page', 'evidence' => 'agent-reported', 'corroboration' => nil }
    run = { 'skill' => 'verify-flagship', 'command' => 'verify-flagship drive slow', 'checked' => 'Rendered /slow',
            'result' => 'Passed', 'not_covered' => 'Nothing.', 'commit' => fixture_ref(ROOT), 'artifacts' => [] }
    description_content.merge('skills_used' => [skill],
                              'companion_results' => [run, run.merge('commit' => 'b' * 40)])
  end

  def fake_gh
    DESCRIPTION_GH.gsub('owner/repo', 'shakacode/shaka')
                  .gsub("'full_name' => 'shakacode/shaka'", "'full_name' => 'ShakaCode/Shaka'")
                  .sub("'sha' => 'c' * 40", "'sha' => ENV.fetch('PREVIEW_HEAD')")
  end
end
