# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require_relative 'cli_opening_check_fakes'
require_relative 'project_guidance_helper'
require 'shaka/publication/publication'

class PublicationTemplateLayoutTest < Minitest::Test
  include CliOpeningCheckFakes

  SUMMARY = 'Reviewers can see the changed behavior.'
  CREDIT = '_PR prepared with [Shaka](https://shaka.shakacode.com/)._'
  MARKER = Shaka::PrTemplate::MARKER
  SHAKA = ['Summary', 'Intent', 'Verification', 'Shaka metrics'].freeze
  SECTIONS = [{ 'heading' => 'Rollout', 'body' => 'Nothing to turn on.' },
              { 'heading' => 'Changelog', 'body' => 'None.' }].freeze

  def test_a_template_without_the_marker_changes_nothing
    usual = render(nil)
    assert_equal [*SHAKA, 'Rollout', 'Changelog'], outline(usual)
    [[], %w[Changelog Rollout], %w[Summary Shaka Rollout]].each do |template|
      assert_equal usual, render(template)
    end
  end

  def test_the_marker_places_shakas_sections_among_the_templates
    rendered = render(['Changelog', MARKER, 'Rollout'])
    assert_equal ['Changelog', *SHAKA, 'Rollout'], outline(rendered)
    assert rendered.start_with?('🤖 '), rendered
    assert rendered.end_with?("\n\n#{CREDIT}\n"), rendered
    assert_operator rendered.index('Checkpoint: _Not published yet._'), :<, rendered.index('## ')
  end

  # Shaka's own sequence never splits, so its notes, such as the evidence fold, stay with their sections.
  def test_a_template_heading_shaka_writes_does_not_move_shakas_section
    rendered = render(['Verification', 'Rollout', MARKER])
    assert_equal ['Rollout', *SHAKA, 'Changelog'], outline(rendered)
    evidence = rendered.index('<summary>Evidence and limitations</summary>')
    assert_operator evidence, :<, rendered.index('## Shaka metrics')
  end

  def test_a_supplied_section_under_a_shaka_heading_stays_after_shakas
    supplied = [{ 'heading' => 'Verification', 'body' => 'All good.' }, *SECTIONS]
    rendered = render(['Verification', 'Rollout', MARKER], supplied)
    assert_equal ['Rollout', *SHAKA, 'Verification', 'Changelog'], outline(rendered)
  end

  def test_sections_the_template_does_not_name_follow_shakas
    rendered = render(['rollout', MARKER, 'Rollout'])
    assert_equal ['Rollout', *SHAKA, 'Changelog'], outline(rendered)
  end

  private

  def render(template, sections = SECTIONS)
    settings = Shaka::PublicationSettings.new(current: { 'pr_description.show_shaka_credit' => true })
    # Prepare reads the outline from the trusted template; the command tests below cover that read.
    settings.instance_variable_set(:@template_headings, template)
    Shaka::Publication.description(description_content.merge('sections' => sections), nil, nil, settings)
  end

  def outline(rendered) = rendered.scan(/^## (.+)$/).flatten
end

class PublicationTemplateLayoutCommandTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes
  include ProjectGuidanceHelper

  COMMAND = SHAKA_COMMAND
  SUMMARY = PublicationTemplateLayoutTest::SUMMARY
  TEMPLATE = "## Deployment\n\n<!-- How to deploy. -->\n\n<!-- shaka -->\n"

  def test_trusted_template_orders_the_published_description
    with_guidance('pr_evidence' => '.agents/pr-evidence.md') do |root|
      write_template(root, TEMPLATE)
      commit(root)
      write_template(root, "<!-- shaka -->\n\n## Deployment\n")
      body = published(root)
      assert_operator body.index('## Deployment'), :<, body.index('## Summary')
    end
  end

  def test_a_guide_naming_the_template_orders_the_description
    with_guidance('pr_evidence' => '.github/pull_request_template.md') do |root|
      write_template(root, TEMPLATE)
      commit(root)
      body = published(root)
      assert_operator body.index('## Deployment'), :<, body.index('## Summary')
    end
  end

  def test_guidance_shows_the_order_shaka_reads
    with_guidance('pr_evidence' => '.agents/pr-evidence.md') do |root|
      write_template(root, TEMPLATE)
      assert guidance('pr_evidence', root, commit(root))
        .end_with?("Shaka read this template's layout as: `## Deployment`, <!-- shaka -->.\n")
    end
  end

  def test_an_unreadable_template_keeps_the_usual_order
    with_guidance('pr_evidence' => '.agents/pr-evidence.md') do |root|
      write_template(root, '')
      commit(root)
      body = published(root)
      assert_operator body.index('## Summary'), :<, body.index('## Deployment')
    end
  end

  def test_template_without_pr_evidence_keeps_the_usual_order
    with_repository do |root|
      write_template(root, TEMPLATE)
      commit(root)
      body = published(root)
      assert_operator body.index('## Summary'), :<, body.index('## Deployment')
    end
  end

  private

  def published(root)
    Dir.mktmpdir do |dir|
      _output, error, status = run_description(dir, root:, ref: fixture_ref(root))
      assert_predicate status, :success?, error
      File.read(File.join(dir, 'published.md'))
    end
  end

  def description_content
    super.merge('sections' => [{ 'heading' => 'Deployment', 'body' => 'Deploys nothing.' }])
  end
end
