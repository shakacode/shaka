# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'tmpdir'
require 'fileutils'
require 'open3'

class DocsNavigationTest < Minitest::Test
  AGENT_LINKS = <<~MARKDOWN
    Read [the review guide](../skills/shaka/references/review.md#choose).
    See [upstream](https://github.com/shakacode/shaka/blob/main/skills/shaka/references/delivery.md).
    [guide]: <../skills/shaka/references/local-review.md>
    <a href="https://github.com/shakacode/shaka/tree/main/skills/shaka/references">all</a>
    Bare: https://github.com/shakacode/shaka/blob/v1/skills/shaka/references/review.md.
    Autolink: <https://github.com/shakacode/shaka/blob/main/skills/shaka/references/publication.md>
    [section](../skills/shaka/references#review) and [query](../skills/shaka/references?page=1)
    <a href=../skills/shaka/references/review.md>unquoted</a>
  MARKDOWN

  def check(sidebar, page = '# What to expect', files = {})
    Dir.mktmpdir do |repository|
      tree = { 'docs/expected-experience.md' => page, 'docs/sidebars.json' => JSON.generate(sidebar) }
      tree.merge(files).each do |path, text|
        FileUtils.mkdir_p(File.dirname(File.join(repository, path)))
        File.write(File.join(repository, path), text)
      end
      system('git', 'init', '-q', repository, exception: true)
      yield repository if block_given?
      Open3.capture3('ruby', File.expand_path('../bin/check-docs-navigation', __dir__), File.join(repository, 'docs'))
    end
  end

  def test_new_page_missing_from_navigation_fails
    output, _, status = check('docsSidebar' => [])
    refute_predicate status, :success?
    assert_includes output, 'expected-experience'
  end

  def test_nested_document_is_reachable
    _, _, status = check('docsSidebar' => [{ 'type' => 'category', 'label' => 'Start',
                                             'items' => ['expected-experience'] }])
    assert_predicate status, :success?
  end

  def test_stale_document_entry_fails
    output, _, status = check('docsSidebar' => %w[expected-experience deleted-guide])
    refute_predicate status, :success?
    assert_includes output, 'deleted-guide'
  end

  def test_links_to_agent_instructions_fail
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, AGENT_LINKS)
    refute_predicate status, :success?
    agent_line = output.lines.grep(/\ALink a human guide/).first
    assert_equal 8, agent_line.scan('expected-experience.md -> ').size
  end

  def test_configuration_links_and_prose_pass
    page = <<~MARKDOWN
      Copy [the defaults](../skills/shaka/config/defaults.yml) and read [settings](settings.md).
      Install the [workflow template](../skills/shaka/config/claude-code-review.yml).
      The agent keeps its procedures in its own references folder.
    MARKDOWN
    _, _, status = check({ 'docsSidebar' => %w[expected-experience settings] }, page,
                         'docs/settings.md' => '# Settings', 'skills/shaka/config/defaults.yml' => "{}\n",
                         'skills/shaka/config/claude-code-review.yml' => "{}\n")
    assert_predicate status, :success?
  end

  GUIDE = "GUIDE = 'https://github.com/shakacode/shaka/blob/main/docs/settings.md#%s'\n"

  SETTINGS = <<~MARKDOWN
    # Settings
    ## Add a second reviewer
    ## `review.ci_review_wait`
    ## Examples
    ## Examples
    ### See [the guide](#examples) first
    <a id="opening_check"></a>
    ```text
    ## Not a heading
    ```
  MARKDOWN

  RESOLVABLE = <<~MARKDOWN
    Read [one](settings.md#add-a-second-reviewer), [two](settings.md#reviewci_review_wait),
    [three](settings.md#examples-1), [four](settings.md#see-the-guide-first),
    [five](<settings.md#opening_check>), and [here](#what-to-expect).

    # What to expect
    ```text
    [ignored](missing.md)
    ```
    `[ignored](missing.md)` and [settings](settings.md).
  MARKDOWN

  def check_links(page, files = {})
    check({ 'docsSidebar' => %w[expected-experience settings] }, page, { 'docs/settings.md' => SETTINGS }.merge(files))
  end

  def test_resolvable_links_and_anchors_pass
    skill = "# Start\nSee [settings](../../docs/settings.md).\n"
    output, _, status = check_links(RESOLVABLE, 'skills/shaka/SKILL.md' => skill,
                                                'skills/shaka/lib/guide.rb' => format(GUIDE, 'add-a-second-reviewer'))
    assert_predicate status, :success?, output
  end

  BROKEN = ['docs/expected-experience.md -> gone.md (missing file)',
            'docs/expected-experience.md -> settings.md#nope (missing anchor)',
            'docs/expected-experience.md -> settings.md#not-a-heading (missing anchor)',
            'docs/expected-experience.md -> guide.mdx#absent (missing anchor)',
            'docs/expected-experience.md -> settings.md#also-nope (missing anchor)',
            'skills/shaka/SKILL.md -> references/missing.md (missing file)'].freeze

  def test_missing_files_and_anchors_fail
    page = "[gone](gone.md), [anchor](settings.md#nope), [code block](settings.md#not-a-heading)\n" \
           "[mdx](guide.mdx#absent) and [defined]\n\n[defined]: settings.md#also-nope\n[^1]: A footnote, not a link.\n"
    output, _, status = check_links(page, 'skills/shaka/SKILL.md' => "[ref](references/missing.md)\n",
                                          'docs/guide.mdx' => '# Guide')
    refute_predicate status, :success?
    assert_equal BROKEN.sort, output.lines.map(&:strip).grep(/ -> /).sort
  end

  def test_docs_anchor_emitted_by_code_must_resolve
    guide = "#{format(GUIDE, 'add-another-reviewer')}PAGE = 'https://github.com/shakacode/shaka/blob/main/docs/gone.md'\n"
    output, _, status = check_links('# What to expect', 'skills/shaka/lib/guide.rb' => guide)
    refute_predicate status, :success?
    assert_includes output, 'skills/shaka/lib/guide.rb -> docs/settings.md#add-another-reviewer (missing anchor)'
    assert_includes output, 'skills/shaka/lib/guide.rb -> docs/gone.md (missing file)'
  end
end

class DocsParserRegressionTest < Minitest::Test
  def check(*) = DocsNavigationTest.new('fixture').check(*)

  def test_empty_link_destinations_refer_to_the_current_page
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, '[Self]() <a href="">Self</a>')
    assert_predicate status, :success?, output
  end

  def test_html_links_can_target_non_heading_ids
    page = '<div id="setup">Setup</div><a href="#setup">Setup</a>'
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    assert_predicate status, :success?, output
  end

  def test_agent_override_files_cannot_be_enrolled_or_linked
    sidebar = { 'docsSidebar' => %w[expected-experience AGENTS.override] }
    page = '[Instructions](AGENTS.override.md)'
    output, _, status = check(sidebar, page, 'docs/AGENTS.override.md' => '# Agent instructions')
    refute_predicate status, :success?, output
    assert_includes output, 'Link a human guide, not agent instructions:'
    assert_includes output, 'expected-experience.md -> AGENTS.override.md'
  end

  def test_missing_markdown_images_still_fail
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, '![Missing](gone.png)')
    refute_predicate status, :success?, output
    assert_includes output, 'gone.png (missing file)'
  end

  def test_padded_html_and_sidebar_urls_are_still_agent_targets
    target = 'https://github.com/shakacode/shaka/blob/main/skills/shaka/references/review.md '
    sidebar = { 'docsSidebar' => ['expected-experience', { 'type' => 'link', 'label' => 'Agent', 'href' => target }] }
    output, _, status = check(sidebar, "<a href=\"#{target}\">Agent</a>")
    refute_predicate status, :success?, output
    assert_includes output, 'Link a human guide, not agent instructions:'
    assert_includes output, 'expected-experience.md -> '
    assert_includes output, 'sidebars.json -> '
  end

  def test_browser_top_links_pass_while_missing_heading_links_fail
    page = '[Top](#top) [Top](#TOP) [Top](#)'
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    assert_predicate status, :success?, output

    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, '[Missing](#absent)')
    refute_predicate status, :success?, output
    assert_includes output, '#absent (missing anchor)'
  end

  def test_query_links_keep_file_and_fragment_validation
    cases = { 'settings.md?from=guide' => nil, 'settings.md?from=guide#add-a-second-reviewer' => nil,
              'settings.md?from=guide#absent' => 'missing anchor', 'gone.md?from=guide' => 'missing file' }
    cases.each do |target, problem|
      output, _, status = DocsNavigationTest.new('fixture').check_links("[Setup](#{target})")
      assert_equal problem.nil?, status.success?, output
      assert_includes output, problem if problem
    end
  end

  def test_raw_refs_named_like_github_views_still_reject_agent_links
    %w[tree blob].each do |ref|
      target = "https://raw.githubusercontent.com/shakacode/shaka/#{ref}/skills/shaka/references/review.md"
      sidebar = { 'docsSidebar' => ['expected-experience', { 'type' => 'link', 'label' => 'Agent', 'href' => target }] }
      output, _, status = check(sidebar, "[Agent](#{target})")
      refute_predicate status, :success?, output
      assert_includes output, "expected-experience.md -> #{target}"
      assert_includes output, "sidebars.json -> #{target}"
    end
  end
end

class DocsFigureCheckTest < Minitest::Test
  FIGURES = { 'img/good.svg' => '<svg xmlns="http://www.w3.org/2000/svg"/>', 'img/empty.svg' => '',
              'img/nested/unclosed.svg' => '<svg><g></svg>', 'img/page.svg' => '<html/>',
              'img/bare.svg' => '<svg/>', 'img/.draft/LOUD.SVG' => '<svg>',
              'sidebars.json' => '{"docsSidebar":["guide"]}', 'guide.md' => '# Guide' }.freeze

  def check(docs)
    FIGURES.each do |path, text|
      FileUtils.mkdir_p(File.dirname(File.join(docs, path)))
      File.write(File.join(docs, path), text)
    end
    Open3.capture2('ruby', File.expand_path('../bin/check-docs-navigation', __dir__), docs)
  end

  def test_figures_must_parse_as_svg
    output, status = Dir.mktmpdir do |repository|
      docs = File.join(repository, 'docs')
      FileUtils.mkdir_p(docs)
      check(docs)
    end
    refute_predicate status, :success?
    malformed = output[/^Figures that do not parse as SVG: (.*)$/, 1].split(', ')
    assert_equal %w[img/.draft/LOUD.SVG img/bare.svg img/empty.svg img/nested/unclosed.svg img/page.svg], malformed.sort
  end
end

class DocsAudienceTest < Minitest::Test
  def check(...) = DocsNavigationTest.new('fixture').check(...)

  def test_new_human_guide_outside_documentation_locations_fails
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide',
                              'new-guides/install.md' => '# Install')
    refute_predicate status, :success?
    assert_includes output, 'Markdown outside established documentation locations: new-guides/install.md'
  end

  def test_new_root_guide_requires_an_explicit_destination
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', 'installation.md' => '# Install')
    refute_predicate status, :success?
    assert_includes output, 'Markdown outside established documentation locations: installation.md'
  end

  def test_agent_entry_point_cannot_become_a_published_page
    sidebar = { 'docsSidebar' => %w[expected-experience SKILL] }
    output, _, status = check(sidebar, '# Guide', 'docs/SKILL.md' => '# Agent instructions')
    refute_predicate status, :success?
    assert_includes output, 'Link a human guide, not agent instructions: SKILL.md'
  end

  def test_ignored_dependency_markdown_is_outside_the_inventory
    files = { '.gitignore' => "vendor/bundle/\n", 'vendor/bundle/example/README.md' => '# Dependency' }
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', files)
    assert_predicate status, :success?, output
  end

  def test_moving_a_tracked_guide_does_not_require_staging_first
    files = { 'notes.md' => '# Notes' }
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', files) do |repository|
      system('git', '-C', repository, 'add', 'notes.md', exception: true)
      FileUtils.mkdir_p(File.join(repository, 'internal'))
      FileUtils.mv(File.join(repository, 'notes.md'), File.join(repository, 'internal/notes.md'))
    end
    assert_predicate status, :success?, output
  end

  AGENT_DESTINATIONS = %w[../skills/mct/SKILL.md ../skills/shaka/config/review-prompt.md
                          ../skills/shaka/config/workflow.yml
                          ../.agents/shaka/instructions/review.md ../AGENTS.md ../agents.override.md
                          ../CLAUDE.local.md ../GEMINI.md
                          https://github.com/shakacode/shaka/blob/main/AGENTS.日本.md
                          ../.github/copilot-instructions.md ../.github/instructions/ruby.instructions.md
                          ../.claude/agents/reviewer.md ../.cursor/rules/review.mdc
                          ../.github/agents/reviewer.agent.md ../.codex/skills/team/references/setup.md
                          ../.gemini/context.md ../.cursorrules
                          ../skills/shaka/references/../SKILL.md
                          https://github.com/shakacode/shaka/blame/main/skills/shaka/references/review.md
                          https://raw.githubusercontent.com/shakacode/shaka/main/skills/shaka/SKILL.md
                          https://raw.githubusercontent.com/shakacode/shaka/refs/heads/main/skills/shaka/references/review.md
                          https://github.com/shakacode/shaka/blob/main/skills/shaka/references/REVIEW.MD
                          https://github.com/shakacode/shaka/blob/main/skills/shaka/%53KILL.md].freeze

  def test_all_shaka_agent_markdown_links_fail
    paths = AGENT_DESTINATIONS
    page = paths.map { |path| "[agent](#{path})" }.join("\n")
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    refute_predicate status, :success?
    agent_line = output.lines.grep(/\ALink a human guide/).first
    assert(paths.all? { |path| agent_line.include?(path) }, agent_line)
  end

  def test_sidebar_links_to_agent_instructions_fail
    sidebar = { 'docsSidebar' => ['expected-experience', { 'type' => 'link', 'label' => 'Agent',
                                                           'href' => '../skills/shaka/SKILL.md' }] }
    output, _, status = check(sidebar)
    refute_predicate status, :success?
    assert_includes output, 'sidebars.json -> ../skills/shaka/SKILL.md'
  end

  def test_human_pages_can_discuss_agents_and_skills
    files = { 'docs/claude-guide.md' => '# Claude', 'docs/skills/overview.md' => '# Skills' }
    sidebar = { 'docsSidebar' => %w[expected-experience claude-guide skills/overview] }
    page = '[Claude](claude-guide.md) and [skills](skills/overview.md)'
    output, _, status = check(sidebar, page, files)
    assert_predicate status, :success?, output
  end

  def test_links_to_agent_directories_fail
    page = '[Skill](https://github.com/shakacode/shaka/tree/main/skills/shaka/)'
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    refute_predicate status, :success?
    assert_includes output, 'Link a human guide, not agent instructions:'
  end

  ALTERNATE_URLS = %w[https://GITHUB.COM/shakacode/shaka/blob/main/skills/shaka/references/review.md
                      https://github.com:443/shakacode/shaka/blob/main/skills/shaka/references/review.md
                      https://github.com/shakacode/shaka/blob/main/%73kills/shaka/references/review.md
                      https://github.com/shakacode/shaka/blob/main/skills/shaka/references/review.md#café
                      https://github.com/shakacode/shaka/blob/main/skills/shaka/references/café.md
                      HTTPS://github.com/shakacode/shaka/blob/main/skills/shaka/references/review.md
                      https://www.github.com/ShakaCode/Shaka/edit/main/skills/shaka/SKILL.md].freeze

  def test_alternate_reference_urls_are_still_rejected
    targets = ALTERNATE_URLS
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, targets.join("\n"))
    refute_predicate status, :success?
    targets.each { |target| assert_includes output, target }
  end

  def test_top_level_agent_directory_sidebar_link_fails
    sidebar = { 'docsSidebar' => ['expected-experience',
                                  { 'type' => 'link', 'label' => 'Agent', 'href' => '../skills' }] }
    output, _, status = check(sidebar)
    refute_predicate status, :success?
    assert_includes output, 'sidebars.json -> ../skills'
  end

  def test_other_projects_skill_citations_are_allowed
    page = '[Reference](https://github.com/example/other/blob/main/skills/shaka/references/guide.md)'
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    assert_predicate status, :success?, output
  end
end

class DocsAudienceRoutesTest < Minitest::Test
  def check(*) = DocsNavigationTest.new('fixture').check(*)

  def test_gem_and_contributor_documentation_have_separate_destinations
    files = { 'README.gem.md' => '# Gem', 'CONTRIBUTING.md' => '# Contribute',
              'contributing/development.md' => '# Development', 'internal/notes.md' => '# Record',
              'AGENTS.override.md' => '# Local agent instructions' }
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', files)
    assert_predicate status, :success?, output
  end

  def test_human_skill_guides_allow_source_urls_and_site_routes
    source = 'https://github.com/shakacode/shaka/blob/main/docs/skills/overview.md'
    files = { 'docs/skills/overview.md' => '# Skills' }
    sidebar = { 'docsSidebar' => ['expected-experience', 'skills/overview',
                                  { 'type' => 'link', 'label' => 'Skills', 'href' => source },
                                  { 'type' => 'link', 'label' => 'Skills route', 'href' => '/skills/overview' }] }
    page = "[Source](#{source}) and [route](/skills/overview)"
    output, _, status = check(sidebar, page, files)
    assert_predicate status, :success?, output
  end

  def test_quoted_and_list_reference_definitions_cannot_hide_agent_links
    ['> ', '> > ', '- '].each do |prefix|
      page = "#{prefix}[Review][prompt]\n#{prefix}\n#{prefix}[prompt]: ../skills/shaka/config/review-prompt.md\n"
      output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
      refute_predicate status, :success?, output
      assert_includes output, 'Link a human guide, not agent instructions:'
    end
  end

  def test_multiline_quoted_reference_is_checked
    page = "> [Review][prompt]\n>\n> [prompt]:\n>   ../skills/shaka/config/review-prompt.md\n"
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    refute_predicate status, :success?, output
    assert_includes output, 'Link a human guide, not agent instructions:'
  end

  def test_source_url_dot_segments_are_normalized_in_guides_and_sidebar
    target = 'https://github.com/shakacode/shaka/blob/main/docs/../skills/shaka/references/review.md'
    sidebar = { 'docsSidebar' => ['expected-experience', { 'type' => 'link', 'label' => 'Review', 'href' => target }] }
    files = { 'skills/shaka/references/review.md' => '# Review' }
    output, _, status = check(sidebar, "[Review](#{target})", files)
    refute_predicate status, :success?, output
    assert_includes output, "expected-experience.md -> #{target}"
    assert_includes output, "sidebars.json -> #{target}"
  end
end

class DocsAudienceExamplesTest < Minitest::Test
  def check(*) = DocsNavigationTest.new('fixture').check(*)

  def test_html_entities_cannot_hide_an_agent_destination
    page = '<a href="https://github.com/shakacode/shaka/blob/main/&#115;kills/shaka/references/review.md">Review</a>'
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    refute_predicate status, :success?
    assert_includes output, 'Link a human guide, not agent instructions:'
  end

  def test_html_attribute_case_does_not_hide_an_agent_destination
    page = '<a HREF="//github.com/shakacode/shaka/blob/main/skills/shaka/config/review-prompt.md">Review</a>'
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    refute_predicate status, :success?
    assert_includes output, 'Link a human guide, not agent instructions:'
  end

  def test_hidden_product_guide_is_not_silently_omitted
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide',
                              'docs/.draft/install.md' => '# Install')
    refute_predicate status, :success?
    assert_includes output, 'Site-excluded Markdown: .draft/install.md; move product guides to visible docs/ paths'
    refute_includes output, 'Missing from docs/sidebars.json: .draft/install'
  end

  def test_uppercase_site_extension_requires_relocation_instead_of_enrollment
    sidebar = { 'docsSidebar' => %w[expected-experience INSTALL] }
    output, _, status = check(sidebar, '# Guide', 'docs/INSTALL.MD' => '# Install')
    refute_predicate status, :success?
    assert_includes output, 'Site-excluded Markdown: INSTALL.MD'
    assert_includes output, 'Navigation targets missing pages: INSTALL'
  end

  def test_enrollment_cannot_make_site_excluded_guides_publishable
    %w[.draft/install _draft/install planning/install guides/planning/install .draft _partial].each do |id|
      sidebar = { 'docsSidebar' => ['expected-experience', id] }
      output, _, status = check(sidebar, '# Guide', "docs/#{id}.md" => '# Install')
      refute_predicate status, :success?, id
      assert_includes output, "Site-excluded Markdown: #{id}.md"
      assert_includes output, "Navigation targets missing pages: #{id}"
    end
  end

  def test_live_links_after_code_examples_are_checked
    page = "~~~text\nExample\n~~~~\n[Agent](../skills/shaka/references/review.md)\n"
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    refute_predicate status, :success?
    assert_includes output, 'Link a human guide, not agent instructions:'
  end

  def test_code_examples_and_unused_definitions_are_not_links
    page = <<~MARKDOWN
      ```markdown
      [Agent](../skills/shaka/config/review-prompt.md)
      ```
      `[Agent](../AGENTS.md)`

      [unused]: ../skills/shaka/config/review-prompt.md
    MARKDOWN
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    assert_predicate status, :success?, output
  end
end

class DocsCaseInventoryTest < Minitest::Test
  def check(...) = DocsNavigationTest.new('fixture').check(...)

  def test_uppercase_markdown_requires_a_destination_in_git_and_exports
    paths = %w[new-guides/INSTALL.MD new-guides/install.MdX]
    paths.product([true, false]).each do |path, git|
      output, _, status = uppercase_fixture(path, git)
      refute_predicate status, :success?, "#{git}: #{path}"
      assert_includes output, "Markdown outside established documentation locations: #{path}"
    end
  end

  def test_uppercase_markdown_can_have_an_established_non_site_destination
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide',
                              'contributing/INSTALL.MD' => '# Install')
    assert_predicate status, :success?, output
  end

  private

  def uppercase_fixture(path, git)
    check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', path => '# Install') do |root|
      if git
        system('git', '-C', root, 'add', path, exception: true)
      else
        FileUtils.remove_entry(File.join(root, '.git'))
      end
    end
  end
end

class DocsIgnoredInventoryTest < Minitest::Test
  def check(...) = DocsNavigationTest.new('fixture').check(...)

  def test_ignored_docs_are_skipped_until_tracked
    files = { '.gitignore' => "/docs/.cache/\n", 'docs/.cache/README.md' => '[Generated](missing.md)' }
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', files)
    assert_predicate status, :success?, output
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', files) do |root|
      system('git', '-C', root, 'add', '-f', 'docs/.cache/README.md', exception: true)
    end
    refute_predicate status, :success?
    assert_includes output, 'Site-excluded Markdown: .cache/README.md'
    assert_includes output, 'docs/.cache/README.md -> missing.md (missing file)'
  end
end
