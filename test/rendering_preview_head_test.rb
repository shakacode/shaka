# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'tmpdir'
require 'shaka/publication/rendering_preview'

# A preview renders with every publication file at the head, except the guards and writes that stay installed.
class RenderingPreviewHeadTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  DIRECTORY = Shaka::RenderingPreview::DIRECTORY

  # A head missing an installed renderer was not rebased; the installed copy never stands in for it.
  def test_a_head_missing_an_installed_renderer_is_refused
    %w[metrics.rb task_source_line.rb].each do |name|
      error = assert_raises(Shaka::Error, name) { preview(without: name) }
      assert_includes error.message, "lacks installed #{DIRECTORY}#{name}", name
    end
  end

  def test_a_new_renderer_previews_without_a_list_edit
    preview(files: { 'head_probe.rb' => "module Shaka\n  module HeadProbe\n    VALUE = :head\n  end\nend\n" })
    assert_equal :head, Shaka::HeadProbe::VALUE
  end

  # A head that changes a guard or the GitHub write cannot have its own description checked or stored by that change.
  def test_a_changed_guard_or_write_stays_installed
    guards = Shaka::RenderingPreview::INSTALLED.to_h { |path| [File.basename(path), "\nraise 'head copy loaded'\n"] }
    assert_includes guards.keys, 'feature_guard.rb'
    assert_includes guards.keys, 'review_effort_floor.rb'
    assert_includes guards.keys, 'publishing.rb'
    assert_match(/body\n<!-- shaka:rendering-preview [0-9a-f]{40} -->/, preview(appends: guards))
  end

  # The write's table check follows rendering, so it counts separators with the installed prose filter.
  def test_a_previewed_text_helper_cannot_weaken_the_write_check
    original = Shaka::PublicationText.method(:prose)
    prose = "module Shaka\n  module PublicationText\n    def self.prose(_) = ''\n  end\nend\n"
    preview(appends: { 'text.rb' => "\n#{prose}" })
    assert_equal '| a |', Shaka::PublicationText.prose('| a |')
    error = assert_raises(Shaka::Error) { Shaka::RenderedProse.check!("| a |\n| --- |\n", '<p>a</p>') }
    assert_includes error.message, 'rendered 0 of 1 table'
  ensure
    Shaka::PublicationText.define_singleton_method(:prose, original)
  end

  # Sorted by name the caller would load first; its require_relative line puts its callee ahead of it.
  def test_a_callee_loads_before_its_caller
    preview(files: { 'aa_order_caller.rb' => "require_relative 'zz_order_callee'\n\n" \
                                             "module Shaka\n  OrderCaller = OrderCallee\nend\n",
                     'zz_order_callee.rb' => "module Shaka\n  module OrderCallee; end\nend\n" })
    assert_same Shaka::OrderCallee, Shaka::OrderCaller
  end

  def test_a_require_cycle_or_a_missing_sibling_is_refused
    cycle = { 'cycle_a.rb' => "require_relative 'cycle_b'\n", 'cycle_b.rb' => "require_relative 'cycle_a'\n" }
    error = assert_raises(Shaka::Error) { preview(files: cycle) }
    assert_includes error.message, "require_relative cycle #{DIRECTORY}cycle_a.rb -> #{DIRECTORY}cycle_b.rb -> " \
                                   "#{DIRECTORY}cycle_a.rb"

    error = assert_raises(Shaka::Error) { preview(files: { 'lonely.rb' => "require_relative 'absent'\n" }) }
    assert_includes error.message, "#{DIRECTORY}lonely.rb requires #{DIRECTORY}absent.rb, absent at the head"
  end

  private

  # Renders a commit holding this checkout's publication files, less one, plus new files and appended lines.
  def preview(without: nil, files: {}, appends: {})
    Dir.mktmpdir do |dir|
      head = fixture_head(dir, without:, files:, appends:)
      Shaka::RenderingPreview.render(root: dir, head:, repository: 'shakacode/shaka') { 'body' }
    end
  end

  def fixture_head(dir, without:, files:, appends:)
    git(dir, 'init', '-q')
    write_files(File.join(dir, DIRECTORY), without:, files:, appends:)
    git(dir, 'add', '-A')
    git(dir, '-c', 'user.name=t', '-c', 'user.email=t@example.com', '-c', 'commit.gpgsign=false',
        'commit', '-q', '-m', 'fixture')
    git(dir, 'rev-parse', 'HEAD').strip
  end

  def write_files(target, without:, files:, appends:)
    FileUtils.mkdir_p(target)
    Dir[File.join(ROOT, DIRECTORY, '*.rb')].each { |path| FileUtils.cp(path, target) }
    FileUtils.rm(File.join(target, without)) if without
    files.each { |name, source| File.write(File.join(target, name), source) }
    appends.each { |name, source| File.write(File.join(target, name), source, mode: 'a') }
  end

  def git(dir, *)
    output, status = Open3.capture2e('git', '-C', dir, *)
    assert_predicate status, :success?, output
    output
  end
end
