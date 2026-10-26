# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/rendering_preview'
require 'shaka/handoff'

# A self-preview must not change the installation that verifies the existing evidence.
class RenderingPreviewTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  SCRIPT = <<~RUBY
    require 'shaka/publication/publication'
    require 'shaka/publication/rendering_preview'
    require 'shaka/doctor/installation_identity'
    root = ARGV.fetch(0)
    head, = Open3.capture2('git', '-C', root, 'rev-parse', 'HEAD')
    before = Shaka::Doctor::InstallationIdentity.read
    # Evidence reading, verification, and publication policy must stay the installed copies.
    settings = Shaka::PublicationSettings
    readers = %i[prepare verify current_settings refuse_free_form!]
    policy = %i[initialize include_checkout_path? path_redaction attribution? human_comments? human_comment_rows]
    guarded = -> { readers.map { settings.method(it) } + policy.map { settings.instance_method(it) } }
    installed = guarded.call
    result = Shaka::RenderingPreview.render(root: root, head: head.strip, repository: 'shakacode/shaka') { 'body' }
    abort 'installation changed' unless before == Shaka::Doctor::InstallationIdentity.read
    abort 'evidence or policy replaced' unless installed == guarded.call
    puts result
  RUBY

  def test_preview_loads_renderers_without_replacing_evidence_verification
    out, err, status = Open3.capture3(RbConfig.ruby, '-I', File.join(ROOT, 'skills/shaka/lib'), '-e', SCRIPT, ROOT)
    assert_predicate status, :success?, err
    assert_match(/body\n<!-- shaka:rendering-preview [0-9a-f]{40} -->/, out)
  end

  def test_wrong_repository_or_moved_checkout_is_refused
    assert_raises(Shaka::Error) do
      Shaka::RenderingPreview.render(root: ROOT, head: 'a' * 40, repository: 'other/repo') { flunk }
    end
    assert_raises(Shaka::Error) do
      Shaka::RenderingPreview.render(root: ROOT, head: 'a' * 40, repository: 'shakacode/shaka') { flunk }
    end
  end

  def test_handoff_owes_a_missing_or_stale_preview_even_when_other_artifacts_are_current
    github = preview_github
    [nil, "<!-- shaka:rendering-preview #{'b' * 40} -->"].each do |body|
      result = rendering_fact(github, body)
      assert_includes result.fetch('owed').join, 'description --rendering-preview-root'
    end
  end

  def test_current_preview_satisfies_handoff
    result = rendering_fact(preview_github, "<!-- shaka:rendering-preview #{'a' * 40} -->")
    assert_empty result.fetch('owed')
    assert_equal 'rendering preview aaaaaaa', result.fetch('fact')
  end

  def test_other_artifact_renderers_cannot_pass_with_a_description_marker
    %w[walkthrough/history.rb local_review/loop_comment.rb post_implementation/publication.rb].each do |path|
      github = preview_github
      github.define_singleton_method(:api_list) { |_query| [{ 'filename' => "skills/shaka/lib/shaka/#{path}" }] }
      assert Shaka::RenderingPreview.required?(github)
      result = rendering_fact(github, "<!-- shaka:rendering-preview #{'a' * 40} -->")
      assert_includes result.fetch('owed').join, path
      assert_includes result.fetch('owed').join, 'does not yet load'
    end
  end

  def test_settings_and_history_renderers_are_previewed
    github = preview_github(%w[provenance_history settings settings_table])
    assert_empty rendering_fact(github, "<!-- shaka:rendering-preview #{'a' * 40} -->").fetch('owed')
  end

  def test_fork_prs_do_not_owe_an_unsafe_preview
    result = rendering_fact(preview_github, nil, source: 'contributor/shaka')
    assert_empty result.fetch('owed')
    assert_equal 'rendering preview skipped', result.fetch('fact')
  end

  def test_repository_casing_cannot_skip_a_required_preview
    result = rendering_fact(preview_github, nil, source: 'ShakaCode/Shaka')
    assert_includes result.fetch('owed').join, 'description --rendering-preview-root'
  end

  def test_ordinary_projects_need_no_self_hosted_preview_or_extra_read
    github = Object.new
    def github.repository = 'owner/repo'
    refute Shaka::RenderingPreview.required?(github)
  end

  def test_unsupported_renderers_block_instead_of_publishing_an_incomplete_preview
    github = preview_github
    def github.api_list(_path) = [{ 'filename' => 'skills/shaka/lib/shaka/publication/text.rb' }]
    pull = { 'head' => { 'repo' => { 'full_name' => github.repository } } }
    error = assert_raises(Shaka::Error) do
      Shaka::RenderingPreview.publish({ rendering_preview_root: ROOT }, pull, github) { flunk }
    end
    assert_includes error.message, 'does not yet load'
  end

  private

  def preview_github(renderers = %w[metrics])
    github = Object.new
    def github.repository = 'shakacode/shaka'
    def github.number = 860
    files = renderers.map { |name| { 'filename' => "#{Shaka::RenderingPreview::DIRECTORY}#{name}.rb" } }
    github.define_singleton_method(:api_list) { |_path| files }
    github
  end

  def rendering_fact(github, body, source: github.repository)
    head = { 'sha' => 'a' * 40, 'repo' => { 'full_name' => source } }
    github.define_singleton_method(:api) { |_path| { 'body' => body, 'head' => head } }
    handoff = Shaka::Handoff.new(github)
    handoff.instance_variable_set(:@owed, [])
    handoff.instance_variable_set(:@notes, [])
    fact = handoff.send(:rendering_fact, 'a' * 40)
    { 'owed' => handoff.instance_variable_get(:@owed), 'fact' => fact }
  end
end
