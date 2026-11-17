# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require_relative 'cli_opening_check_fakes'
require_relative 'project_guidance_helper'
require 'shaka/pr_template'
require 'shaka/publication/publication'

class PublicationTemplateLayoutTest < Minitest::Test
  include CliOpeningCheckFakes

  SUMMARY = 'Reviewers can see the changed behavior.'
  CREDIT = '_PR prepared with [Shaka](https://shaka.shakacode.com/)._'
  DEFAULT_ORDER = ['Summary', 'Intent', 'Verification', '<details> Evidence and limitations', 'Shaka metrics',
                   'Deployment'].freeze

  def test_template_headings_skip_comments_code_and_other_levels
    template = <<~MARKDOWN
      ## Summary
      <!-- Describe the change.
      ## Not a heading -->
      ## Shaka ##
      ```text
      ## Inside a fence
      ```
      ### Deeper
      #Missing space
         ## Indented
      ~~~~
      ## Inside a longer fence
      ~~~
      ## Still inside
      ~~~~
      ## Deployment
    MARKDOWN
    assert_equal %w[Summary Shaka Indented Deployment], Shaka::PrTemplate.headings(template)
  end

  def test_comment_syntax_inside_a_code_block_hides_nothing
    assert_equal %w[Shaka Rollout], Shaka::PrTemplate.headings("```html\n<!--\n```\n## Shaka\n## Rollout\n")
  end

  def test_only_a_bare_fence_closes_a_code_block
    assert_empty Shaka::PrTemplate.headings("```text\n```example\n## Shaka\n```\n")
  end

  def test_comments_on_a_heading_line
    template = "<!-- note --> ## Hidden\n## Summary <!-- what changed -->\nText <!-- open\n## Inside\n-->\n## Shown\n"
    assert_equal %w[Summary Shown], Shaka::PrTemplate.headings(template)
  end

  def test_template_headings_read_windows_line_endings
    template = "## Summary\r\n```\r\n## Code\r\n```\r\n## Shaka Inline\r\n"
    assert_equal ['Summary', 'Shaka Inline'], Shaka::PrTemplate.headings(template)
  end

  def test_a_template_without_a_shaka_heading_changes_nothing
    usual = render(nil)
    assert_equal DEFAULT_ORDER, outline(usual)
    [[], %w[Changelog Summary], ['Deployment', 'Summary', 'Settings changes']].each do |headings|
      assert_equal usual, render(headings)
    end
  end

  def test_inline_heading_places_shaka_sections_between_template_sections
    rendered = render(['Summary', 'Shaka Inline', 'Deployment'])
    assert_equal ['Summary', 'Intent', 'Verification', '<details> Evidence and limitations', 'Shaka metrics',
                  'Deployment'], outline(rendered)
    assert_fixed_ends(rendered)
  end

  def test_collapsed_heading_folds_the_sections_the_template_does_not_name
    rendered = render(%w[Deployment Shaka Summary])
    assert_equal ['Deployment', '<details> Shaka', 'Intent', 'Verification', '<details> Evidence and limitations',
                  'Shaka metrics', 'Summary'], outline(rendered)
    fold = rendered[%r{<details>\n<summary>Shaka</summary>\n\n.*?\n\n</details>\n\n## Summary}m]
    assert fold, rendered
    assert_includes fold, "## Intent\n\n"
    assert_fixed_ends(rendered)
  end

  def test_template_can_place_any_shaka_section
    rendered = render(['Verification', 'Shaka Inline', 'Shaka metrics'])
    assert_equal ['Verification', 'Summary', 'Intent', '<details> Evidence and limitations', 'Deployment',
                  'Shaka metrics'], outline(rendered)
  end

  def test_fold_leaves_steps_besides_merging_visible
    steps = [{ 'when' => 'after merge', 'step' => 'Update Shaka', 'who' => 'Everyone', 'where' => 'Each machine',
               'verify' => 'doctor reports HEALTHY' }]
    rendered = render(%w[Shaka], 'steps_besides_merging' => steps)
    assert_equal ['Before and after merge', '<details> Shaka', 'Summary', 'Intent', 'Verification',
                  '<details> Evidence and limitations', 'Shaka metrics', 'Deployment'], outline(rendered)
  end

  def test_sections_the_template_does_not_name_stay_with_shaka
    sections = [{ 'heading' => 'Notes', 'body' => 'Extra.' }, { 'heading' => 'Deployment', 'body' => 'None.' }]
    rendered = render(['Deployment', 'Shaka Inline', 'Rollout'], 'sections' => sections)
    assert_equal ['Deployment', 'Summary', 'Intent', 'Verification', '<details> Evidence and limitations',
                  'Shaka metrics', 'Notes'], outline(rendered)
  end

  def test_first_shaka_heading_chooses_the_layout
    rendered = render(['Shaka Inline', 'Shaka', 'Deployment'])
    refute_includes rendered, '<summary>Shaka</summary>'
    assert_equal 'Deployment', outline(rendered).last
  end

  def test_supplied_shaka_section_is_refused_when_the_template_marks_one
    sections = [{ 'heading' => 'shaka', 'body' => 'Everything else.' }]
    error = assert_raises(Shaka::Error) { render(%w[Summary Shaka], 'sections' => sections) }
    assert_includes error.message, 'Leave it out of sections'
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

  # Each `##` heading and each fold that holds sections or evidence, in reading order.
  def outline(rendered)
    folds = ['Shaka', 'Evidence and limitations']
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
  TEMPLATE = "## Summary\n\n<!-- What changed. -->\n\n## Shaka\n\n## Deployment\n\n<!-- How to deploy. -->\n"

  def test_trusted_template_orders_the_published_description
    with_guidance('pr_evidence' => '.agents/pr-evidence.md') do |root|
      write_template(root, TEMPLATE)
      commit(root)
      write_template(root, "## Shaka Inline\n\n## Summary\n")
      body = published(root)
      assert_operator body.index('## Summary'), :<, body.index('<summary>Shaka</summary>')
      assert_operator body.index('</details>', body.index('<summary>Shaka</summary>')), :<, body.index('## Deployment')
    end
  end

  def test_a_guide_naming_the_template_orders_the_description
    template = "## Summary\n\n```html\n<!--\n```\n\n## Shaka Inline\n\n## Deployment\n"
    with_guidance('pr_evidence' => '.github/pull_request_template.md') do |root|
      write_template(root, template)
      commit(root)
      body = published(root)
      refute_includes body, '<summary>Shaka</summary>'
      assert_operator body.index('## Shaka metrics'), :<, body.index('## Deployment')
      assert_operator body.index('## Deployment'), :<, body.index('_PR prepared with')
    end
  end

  def test_guidance_tells_the_agent_to_leave_the_shaka_heading_out
    with_guidance('pr_evidence' => '.agents/pr-evidence.md') do |root|
      write_template(root, TEMPLATE)
      assert guidance('pr_evidence', root, commit(root)).end_with?("Leave that heading out of `sections`.\n")
    end
    with_guidance('pr_evidence' => '.github/pull_request_template.md') do |root|
      write_template(root, "## Shaka Inline\n")
      assert_includes guidance('pr_evidence', root, commit(root)), 'marks where Shaka places its own sections'
    end
  end

  def test_template_without_pr_evidence_keeps_the_usual_order
    with_repository do |root|
      write_template(root, TEMPLATE)
      commit(root)
      body = published(root)
      refute_includes body, '<summary>Shaka</summary>'
      assert_operator body.index('## Intent'), :<, body.index('## Deployment')
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
