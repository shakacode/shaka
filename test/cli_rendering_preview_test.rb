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
        body = File.read(File.join(directory, 'published.md'))
        assert Shaka::RenderingPreview.current?(body, fixture_ref(ROOT))
        assert_includes body, '## Shaka metrics'
      end
    end
  end

  private

  def publish_preview(directory, root)
    write_fake_commands(directory)
    path = File.join(directory, 'content.json')
    File.write(path, JSON.generate(description_content))
    args = ['description', 'shakacode/shaka', '1', '--root', root, '--ref', fixture_ref(root),
            '--content-file', path, '--rendering-preview-root', ROOT]
    env = { 'PATH' => "#{directory}:#{ENV.fetch('PATH')}", 'HOME' => directory, 'PREVIEW_HEAD' => fixture_ref(ROOT) }
    Open3.capture3(env, *SHAKA_COMMAND, *args)
  end

  def fake_gh
    DESCRIPTION_GH.gsub('owner/repo', 'shakacode/shaka').sub("'sha' => 'c' * 40", "'sha' => ENV.fetch('PREVIEW_HEAD')")
  end
end
