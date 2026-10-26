# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/rendering_preview'

# A previewed renderer reopens PublicationSettings, so loading it must not replace what verifies evidence.
class RenderingPreviewGuardTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  SCRIPT = <<~RUBY
    require 'shaka/publication/publication'
    require 'shaka/publication/rendering_preview'
    head, = Open3.capture2('git', '-C', ARGV.fetch(0), 'rev-parse', 'HEAD')
    puts Shaka::RenderingPreview.render(root: ARGV.fetch(0), head: head.strip, repository: 'shakacode/shaka') { 'body' }
  RUBY
  DIRECTORY = Shaka::RenderingPreview::DIRECTORY
  # An unrebased head redefines verify; a stray edit could redefine the verdict or a guard constant.
  REDEFINITIONS = ['def self.verify(**) = nil', "def verdict = { 'status' => 'ready' }",
                   "MISSING_REF = 'changed'"].freeze

  # Break: an unrebased head whose settings.rb still defines verify replaced the installed check.
  def test_a_head_that_redefines_settings_verification_or_policy_is_refused
    REDEFINITIONS.each do |line|
      _out, err, status = preview_with("\nmodule Shaka\n  class PublicationSettings\n    #{line}\n  end\nend\n")
      refute_predicate status, :success?, line
      assert_includes err, 'redefines settings verification or policy', line
    end
  end

  def test_the_current_renderers_load_without_refusal
    out, err, status = preview_with('')
    assert_predicate status, :success?, err
    assert_includes out, 'body'
  end

  private

  def preview_with(addition)
    Dir.mktmpdir do |root|
      commit_renderers(root) { File.write(File.join(root, "#{DIRECTORY}settings.rb"), addition, mode: 'a') }
      Open3.capture3(RbConfig.ruby, '-I', File.join(ROOT, 'skills/shaka/lib'), '-e', SCRIPT, root)
    end
  end

  def commit_renderers(root)
    Shaka::RenderingPreview::RENDERERS.each do |path|
      FileUtils.mkdir_p(File.dirname(File.join(root, path)))
      FileUtils.cp(File.join(ROOT, path), File.join(root, path))
    end
    yield
    git(root, 'init', '-q')
    git(root, 'add', '.')
    git(root, '-c', 'user.name=t', '-c', 'user.email=t@example.com', '-c', 'commit.gpgsign=false',
        'commit', '-qm', 'head')
  end

  def git(root, *) = system('git', '-C', root, *, exception: true)
end
