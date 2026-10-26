# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'tmpdir'
require 'shaka/publication/rendering_preview'

# A preview renders only with the head's own renderers.
class RenderingPreviewHeadTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  # A head missing any listed renderer is refused, so the installed copy never stands in for it.
  def test_a_head_missing_a_listed_renderer_is_refused
    %w[metrics.rb task_source_line.rb].each do |name|
      Dir.mktmpdir do |dir|
        head = fixture_head(dir, without: name)
        error = assert_raises(Shaka::Error, name) do
          Shaka::RenderingPreview.render(root: dir, head:, repository: 'shakacode/shaka') { flunk }
        end

        assert_includes error.message, 'Cannot read rendering preview', name
      end
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
    FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
    FileUtils.cp(File.join(ROOT, path), File.join(dir, path))
  end

  def git(dir, *)
    output, status = Open3.capture2e('git', '-C', dir, *)
    assert_predicate status, :success?, output
    output
  end
end
