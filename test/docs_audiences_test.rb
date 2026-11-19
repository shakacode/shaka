# frozen_string_literal: true

require_relative 'support/docs_navigation_fixture'

class DocsAudienceTest < Minitest::Test
  include DocsNavigationFixture

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
  include DocsNavigationFixture

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
  include DocsNavigationFixture

  def test_agent_reference_directory_remains_protected_for_other_extensions
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] },
                              '[Procedure](../skills/shaka/references/procedure.txt)',
                              'skills/shaka/references/procedure.txt' => 'Agent procedure')
    refute_predicate status, :success?
    assert_includes output, 'Link a human guide, not agent instructions:'
  end

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

class DocsHtmlDestinationsTest < Minitest::Test
  include DocsNavigationFixture

  def test_html5_named_entities_resolve_before_destination_classification
    page = '<a href="&period;&period;&sol;skills&sol;shaka&sol;references&sol;review.md">Review</a>'
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    refute_predicate status, :success?
    assert_includes output, 'Link a human guide, not agent instructions:'
  end

  def test_image_maps_and_svg_links_keep_the_agent_destination_guard
    pages = ['<map name="guide"><area href="../skills/shaka/references/review.md"></map>',
             '<svg xmlns:xlink="http://www.w3.org/1999/xlink">' \
             '<a xlink:href="../skills/shaka/references/review.md">Review</a></svg>']
    pages.each do |page|
      output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
      refute_predicate status, :success?
      assert_includes output, 'Link a human guide, not agent instructions:'
    end
  end

  def test_human_image_map_destination_is_allowed
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] },
                              '<map name="guide"><area href="expected-experience.md"></map>')
    assert_predicate status, :success?, output
  end

  def test_cdn_repository_names_are_case_insensitive
    page = '[Review](https://cdn.jsdelivr.net/gh/ShakaCode/Shaka@main/skills/shaka/references/review.md)'
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    refute_predicate status, :success?
    assert_includes output, 'Link a human guide, not agent instructions:'
  end
end

class DocsSlashRefTest < Minitest::Test
  include DocsNavigationFixture

  def test_qualified_hex_refs_keep_branch_semantics
    %w[heads tags].each do |namespace|
      prefix = "https://raw.githubusercontent.com/shakacode/shaka/refs/#{namespace}/#{'a' * 40}/topic"
      target = "#{prefix}/skills/shaka/references/review.md"
      output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, "[Agent](#{target})")
      refute_predicate status, :success?, output
      assert_includes output, 'Link a human guide, not agent instructions:'
    end
  end

  def test_immutable_human_paths_are_not_rewritten_as_agent_paths
    prefixes = ["https://github.com/shakacode/shaka/blob/#{'a' * 40}",
                "https://raw.githubusercontent.com/shakacode/shaka/#{'a' * 40}",
                "https://cdn.jsdelivr.net/gh/shakacode/shaka@#{'a' * 40}"]
    prefixes.each { |prefix| assert_immutable_source_links(prefix) }
  end

  def assert_immutable_source_links(prefix)
    human = 'examples/skills/shaka/references/guide'
    sidebar = { 'docsSidebar' => ['expected-experience', human] }
    files = { "docs/#{human}.md" => '# Human source' }
    output, errors, status = check(sidebar, "[Human](#{prefix}/docs/#{human}.md)", files)
    assert_predicate status, :success?, "#{output}\n#{errors}"
    output, _, status = check(sidebar, "[Agent](#{prefix}/skills/shaka/references/review.md)", files)
    refute_predicate status, :success?, output
  end

  def test_legacy_references_boundary_survives_slash_refs
    prefixes = %w[https://github.com/shakacode/shaka/blob/jg-codex/1-documentation-audiences
                  https://raw.githubusercontent.com/shakacode/shaka/jg-codex/1-documentation-audiences
                  https://cdn.jsdelivr.net/gh/shakacode/shaka@jg-codex/1-documentation-audiences]
    prefixes.each { |prefix| assert_source_links(prefix) }
  end

  def assert_source_links(prefix)
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] },
                              "[Agent](#{prefix}/skills/shaka/references/review.md)")
    refute_predicate status, :success?, output
    output, errors, status = check({ 'docsSidebar' => ['expected-experience'] },
                                   "[Guide](#{prefix}/docs/settings.md)")
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end
end
