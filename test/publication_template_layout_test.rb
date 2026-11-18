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
  DEFAULT_ORDER = ['Summary', 'Intent', 'Verification', '<details> Evidence and limitations', 'Shaka metrics',
                   'Deployment'].freeze

  def test_a_template_without_a_shaka_heading_changes_nothing
    usual = render(nil)
    assert_equal DEFAULT_ORDER, outline(usual)
    [[], %w[Changelog Summary], ['Deployment', 'Summary', 'Settings changes']].each do |headings|
      assert_equal usual, render(headings)
    end
  end

  def test_shaka_heading_places_shaka_sections_between_template_sections
    rendered = render(%w[Summary Shaka Deployment])
    assert_equal ['Summary', 'Intent', 'Verification', '<details> Evidence and limitations', 'Shaka metrics',
                  'Deployment'], outline(rendered)
    assert_fixed_ends(rendered)
    rendered = render(%w[Deployment Shaka Summary])
    assert_equal ['Deployment', 'Intent', 'Verification', '<details> Evidence and limitations', 'Shaka metrics',
                  'Summary'], outline(rendered)
    assert_fixed_ends(rendered)
  end

  def test_template_can_place_any_shaka_section
    rendered = render(['Verification', 'Shaka', 'Shaka metrics'])
    assert_equal ['Verification', '<details> Evidence and limitations', 'Summary', 'Intent', 'Deployment',
                  'Shaka metrics'], outline(rendered)
  end

  def test_evidence_stays_with_shakas_own_verification
    sections = [{ 'heading' => 'Verification', 'body' => 'Supplied.' }]
    rendered = render(%w[Shaka], 'sections' => sections)
    assert_equal ['Summary', 'Intent', 'Verification', '<details> Evidence and limitations', 'Shaka metrics',
                  'Verification'], outline(rendered)
  end

  def test_sections_the_template_does_not_name_stay_with_shaka
    sections = [{ 'heading' => 'Notes', 'body' => 'Extra.' }, { 'heading' => 'Deployment', 'body' => 'None.' }]
    rendered = render(%w[Deployment Shaka Rollout], 'sections' => sections)
    assert_equal ['Deployment', 'Summary', 'Intent', 'Verification', '<details> Evidence and limitations',
                  'Shaka metrics', 'Notes'], outline(rendered)
  end

  def test_supplied_shaka_section_is_refused_when_the_template_marks_one
    sections = [{ 'heading' => 'shaka', 'body' => 'Everything else.' }]
    error = assert_raises(Shaka::Error) { render(%w[Summary Shaka], 'sections' => sections) }
    assert_includes error.message, 'Leave it out of sections'
    ['Shaka ##', 'SHAKA'].each do |heading|
      supplied = [{ 'heading' => heading, 'body' => 'Everything else.' }]
      assert_raises(Shaka::Error) { render(%w[Summary Shaka], 'sections' => supplied) }
    end
    assert_includes render(%w[Summary], 'sections' => sections), "## shaka\n\nEverything else."
  end

  private

  def render(headings, extra = {})
    settings = Shaka::PublicationSettings.new(current: { 'pr_description.show_shaka_credit' => true })
    # Prepare reads these from the trusted template; the command tests below cover that read.
    settings.instance_variable_set(:@template_headings, headings)
    content = description_content.merge('sections' => [{ 'heading' => 'Deployment', 'body' => 'Deploys nothing.' }])
    Shaka::Publication.description(content.merge(extra), nil, nil, settings)
  end

  # Each `##` heading and the evidence fold, in reading order.
  def outline(rendered)
    folds = ['Evidence and limitations']
    rendered.scan(%r{^## (.+)$|^<summary>(.+)</summary>$}).filter_map do |section, fold|
      section || ("<details> #{fold}" if folds.include?(fold))
    end
  end

  def assert_fixed_ends(rendered)
    assert rendered.start_with?('🤖 '), rendered
    assert rendered.end_with?("\n\n#{CREDIT}\n"), rendered
    assert_operator rendered.index('Checkpoint: _Not published yet._'), :<, rendered.index('## ')
  end
end

class PublicationTemplateLayoutCommandTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes
  include ProjectGuidanceHelper

  COMMAND = SHAKA_COMMAND
  SUMMARY = PublicationTemplateLayoutTest::SUMMARY
  TEMPLATE = "## Deployment\n\n<!-- How to deploy. -->\n\n## Shaka\n"

  def test_trusted_template_orders_the_published_description
    with_guidance('pr_evidence' => '.agents/pr-evidence.md') do |root|
      write_template(root, TEMPLATE)
      commit(root)
      write_template(root, "## Shaka\n\n## Deployment\n")
      body = published(root)
      assert_operator body.index('## Deployment'), :<, body.index('## Summary')
    end
  end

  def test_a_guide_naming_the_template_orders_the_description
    template = "## Deployment\n\n```html\n<!--\n```\n\n## Shaka\n"
    with_guidance('pr_evidence' => '.github/pull_request_template.md') do |root|
      write_template(root, template)
      commit(root)
      body = published(root)
      assert_operator body.index('## Deployment'), :<, body.index('## Summary')
      assert_operator body.index('## Shaka metrics'), :<, body.index('_PR prepared with')
    end
  end

  def test_guidance_tells_the_agent_to_leave_the_shaka_heading_out
    with_guidance('pr_evidence' => '.agents/pr-evidence.md') do |root|
      write_template(root, TEMPLATE)
      assert guidance('pr_evidence', root, commit(root)).end_with?("Leave that heading out of `sections`.\n")
    end
    with_guidance('pr_evidence' => '.github/pull_request_template.md') do |root|
      write_template(root, "## Shaka\n")
      assert_includes guidance('pr_evidence', root, commit(root)), 'marks where Shaka places its own sections'
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
