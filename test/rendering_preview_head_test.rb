# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'tmpdir'
require 'shaka/publication/rendering_preview'

# A preview renders with the head's own renderers, falling back only for one the default branch lacks.
class RenderingPreviewHeadTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  # Only a renderer that has not landed may be absent; a head missing any other one is refused.
  def test_a_head_missing_a_landed_renderer_is_refused
    Dir.mktmpdir do |dir|
      head = fixture_head(dir, without: 'metrics.rb')
      error = assert_raises(Shaka::Error) do
        Shaka::RenderingPreview.render(root: dir, head:, repository: 'shakacode/shaka') { flunk }
      end

      assert_includes error.message, 'Cannot read rendering preview'
    end
  end

  def test_a_head_without_the_task_source_renderer_previews_with_the_installed_copy
    Dir.mktmpdir do |dir|
      head = fixture_head(dir, without: 'task_source_line.rb')
      out = Shaka::RenderingPreview.render(root: dir, head:, repository: 'shakacode/shaka') { 'body' }

      assert_equal "body\n<!-- shaka:rendering-preview #{head} -->\n", out
    end
  end

  private

  # A commit holding this checkout's listed renderers, less one.
  def fixture_head(dir, without:)
    git(dir, 'init', '-q')
    Shaka::RenderingPreview::RENDERERS.each { |path| copy(dir, path) unless path.end_with?("/#{without}") }
    git(dir, 'add', '-A')
    git(dir, '-c', 'user.name=t', '-c', 'user.email=t@example.com', 'commit', '-q', '-m', 'fixture')
    git(dir, 'rev-parse', 'HEAD').strip
  end

  def copy(dir, path)
    return unless File.exist?(File.join(ROOT, path))

    FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
    FileUtils.cp(File.join(ROOT, path), File.join(dir, path))
  end

  def git(dir, *)
    output, status = Open3.capture2e('git', '-C', dir, *)
    assert_predicate status, :success?, output
    output
  end
end
