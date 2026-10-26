# frozen_string_literal: true

require_relative 'support/post_implementation_fixture'
require 'shaka/opening_publication'
require 'shaka/configuration'

# A trusted commit with every source a reviewer prompt can draw on, and a change that touches lib/.
module PromptShowFixture
  include PostImplementationFixture

  REPLACEMENT = { 'replacement_prompt_file' => '.agents/review-prompt.md' }.freeze

  private

  def write_trusted_files(root, review)
    super
    { 'AGENTS.md' => "Root criteria\n", 'lib/AGENTS.md' => "Lib criteria\n", 'docs/AGENTS.md' => "Docs criteria\n",
      '.agents/shaka/instructions/review.md' => "Added review rule\n",
      '.agents/shaka/instructions/checkpoint.md' => "Added checkpoint rule\n" }.each do |path, text|
      FileUtils.mkdir_p(File.dirname(File.join(root, path)))
      File.write(File.join(root, path), text)
    end
  end

  def with_change(review = REPLACEMENT)
    Dir.mktmpdir('shaka-prompt-show') do |root|
      Dir.mktmpdir('shaka-prompt-show-cli') do |bin|
        base = trusted_commit(root, review, true)
        File.write(File.join(root, 'lib.rb'), "puts 1\n")
        FileUtils.mkdir_p(File.join(root, 'lib'))
        File.write(File.join(root, 'lib/a.rb'), "puts 2\n")
        commit!(root, 'change lib')
        yield root, base, git!(root, 'rev-parse', 'HEAD').strip, bin
      end
    end
  end

  def show(root, *)
    output, error, status = Open3.capture3(*COMMAND, 'prompt', 'show', *, '--root', root, '--format', 'json')
    assert_predicate status, :success?, "#{output}\n#{error}"
    JSON.parse(output)
  end

  # The shown sections must reproduce the sent prompt exactly, each placeholder standing for whatever it replaced.
  def assert_reproduces(sent, document)
    pattern = document.fetch('sections').map do |section|
      section.fetch('source').start_with?('placeholder:') ? '.*?' : Regexp.escape(unmarked(section.fetch('text')))
    end
    assert_match(/\A#{pattern.join}\z/m, unmarked(sent))
  end

  def seam(review) = super(review.except('pr_description')).merge(review.slice('pr_description'))
  def unmarked(text) = text.gsub(/\h{32}/, 'MARKER')
  def shown_text(document) = document.fetch('sections').map { |section| section.fetch('text') }.join
  def sources(document) = document.fetch('sections').map { |section| section.fetch('source') }
  def sent_prompt(root) = JSON.parse(File.read(File.join(root, 'trace.json'))).fetch('prompt')

  # A commit on another branch whose settings drop the replacement prompt.
  def preview_commit(root, review)
    git!(root, 'switch', '--quiet', '-c', 'settings-preview')
    File.write(File.join(root, '.agents/agent-workflow.yml'), YAML.dump(seam(review)))
    commit!(root, 'preview settings')
    git!(root, 'rev-parse', 'HEAD').strip.tap { git!(root, 'switch', '--quiet', '-') }
  end

  def review_prompt_sent(root, base, head, bin)
    fake_codex(bin, head)
    output, error, status = run_review(root, base, head, bin)
    assert_predicate status, :success?, "#{output}\n#{error}"
    File.unlink(JSON.parse(output).fetch('report'))
    sent_prompt(root)
  end
end

# `prompt show` prints what each reviewer receives, built by the code that sends it.
class PromptShowTest < Minitest::Test
  include PromptShowFixture

  def test_the_code_review_prompt_matches_what_review_run_sends
    with_change do |root, base, head, bin|
      sent = review_prompt_sent(root, base, head, bin)
      document = show(root, 'review', '--ref', base, '--head', head, '--base', base, '--reviewer', 'openai/codex')

      assert_reproduces(sent, document)
      assert_includes sources(document), "replacement .agents/review-prompt.md@#{base} (review.replacement_prompt_file)"
      assert_includes sources(document), "AGENTS.md lib/AGENTS.md@#{base}"
      refute_includes sources(document), "AGENTS.md docs/AGENTS.md@#{base}"
    end
  end

  def test_the_checkpoint_prompt_matches_what_the_checkpoint_sends
    with_change({}) do |root, base, head, bin|
      fake_checkpoint(bin, head)
      result, status = run_checkpoint(root, base, head, bin)
      assert_predicate status, :success?, result.to_s

      document = show(root, 'checkpoint', '--ref', base, '--head', head, '--base', base)
      assert_reproduces(sent_prompt(root), document)
      assert_includes sources(document), "custom instructions .agents/shaka/instructions/checkpoint.md@#{base}, " \
                                         'after the built-in precedence note'
    end
  end

  # With no opening reviewer configured, the check returns the exact prompt a model would receive.
  def test_the_opening_prompt_matches_what_the_opening_check_sends
    opening = { 'pr_description' => { 'opening_check' => { 'replacement_prompt_file' => '.agents/codex-prompt.md' } } }
    with_change(opening) do |root, base, _head, _bin|
      result = Shaka::OpeningPublication.new(root:, ref: base).call("Opens the repository.\n")
      assert_equal 'host_check', result.fetch('status'), result.to_s

      document = show(root, 'opening', '--ref', base)
      assert_reproduces(result.fetch('prompt'), document)
      setting = 'pr_description.opening_check.replacement_prompt_file'
      assert_equal ["replacement .agents/codex-prompt.md@#{base} (#{setting})", 'built-in: data rule',
                    'placeholder: first paragraph of the PR description summary'], sources(document)
    end
  end

  def test_without_a_change_nested_criteria_are_listed_and_not_shown_as_sent
    with_change do |root, base, _head, _bin|
      document = show(root, 'review', '--ref', base, '--reviewer', 'openai/codex')

      assert_includes sources(document), "AGENTS.md AGENTS.md@#{base}"
      refute(sources(document).any? { |source| source.include?('lib/AGENTS.md') })
      assert_equal ['docs/AGENTS.md is added when a change touches docs/',
                    'lib/AGENTS.md is added when a change touches lib/'], document.fetch('notes')
    end
  end

  def test_a_local_draft_shows_working_tree_edits_and_labels_every_section
    with_change do |root, base, _head, _bin|
      File.write(File.join(root, '.agents/shaka/instructions/review.md'), "Draft review rule\n")
      document = show(root, 'review', '--local', '--reviewer', 'openai/codex')

      assert(sources(document).all? { |source| source.start_with?('untrusted draft: ') })
      assert_includes shown_text(document), 'Draft review rule'
      refute_equal base, document.fetch('settings_ref')
      assert_includes git!(root, 'status', '--porcelain'), '.agents/shaka/instructions/review.md'
    end
  end

  # Reviewers read a selected preview's settings, so the report names that commit, not --ref.
  def test_a_settings_preview_is_reported_as_the_settings_source
    with_change do |root, base, _head, _bin|
      preview = preview_commit(root, {})
      Shaka::Configuration::SettingsPreview.new(root:).start(preview)
      document = show(root, 'review', '--ref', base, '--reviewer', 'openai/codex')

      assert_equal [preview, base, true], document.values_at('settings_ref', 'criteria_ref', 'settings_preview')
      refute(sources(document).any? { |source| source.start_with?('replacement ') })
      assert_includes sources(document), "AGENTS.md AGENTS.md@#{base}"
    end
  end

  def test_the_opening_view_reads_the_prompt_a_settings_preview_names
    with_change do |root, base, _head, _bin|
      opening = { 'opening_check' => { 'replacement_prompt_file' => '.agents/codex-prompt.md' } }
      preview = preview_commit(root, { 'pr_description' => opening })
      Shaka::Configuration::SettingsPreview.new(root:).start(preview)
      document = show(root, 'opening', '--ref', base)

      assert_equal preview, document.fetch('settings_ref')
      assert_includes sources(document).first, "replacement .agents/codex-prompt.md@#{preview}"
      assert_includes shown_text(document), 'Codex-only instructions'
    end
  end

  def test_a_disabled_checkpoint_reports_that_no_prompt_is_sent
    with_change('checkpoint' => { 'enabled' => false }) do |root, base, _head, _bin|
      document = show(root, 'checkpoint', '--ref', base)

      refute document.fetch('enabled')
      assert_empty document.fetch('sections')
    end
  end

  def test_requests_without_one_settings_source_or_with_half_a_change_are_refused
    with_change do |root, base, head, _bin|
      [['--ref', base, '--local'], [], ['--ref', base, '--head', head], ['--ref', 'main']].each do |arguments|
        _, error, status = Open3.capture3(*COMMAND, 'prompt', 'show', 'review', '--root', root, *arguments)
        refute_predicate status, :success?, arguments.join(' ')
        assert_match(/--ref|--local|--head/, error)
      end
    end
  end
end
