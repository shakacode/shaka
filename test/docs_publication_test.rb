# frozen_string_literal: true

require_relative 'support/docs_navigation_fixture'

class DocsLinkedInventoryTest < Minitest::Test
  include DocsNavigationFixture

  def test_linked_ignored_guides_are_not_credited_as_published_targets
    %i[absent regular alias tracked].each do |mode|
      output, errors, status = linked_fixture(mode)
      assert_equal mode == :tracked, status.success?, "#{mode}: #{output}\n#{errors}"
      assert_includes output, 'local.md#setup (missing file)' unless mode == :tracked
    end
  end

  def test_unknown_sidebar_forms_fail_in_every_sidebar
    link = { 'type' => 'link', 'label' => 'Agent', 'href' => '../skills/shaka/references/review.md' }
    sidebar = { 'docsSidebar' => ['expected-experience'], 'otherSidebar' => [{ 'Hidden' => [link] }] }
    _, errors, status = check(sidebar)
    refute_predicate status, :success?
    assert_includes errors, 'Unsupported sidebar item:'
  end

  def test_alternate_docs_casing_cannot_credit_ignored_targets
    %i[regular alias].each do |mode|
      files = { '.gitignore' => "/docs/local.md\n", 'internal/target.md' => '# Setup' }
      output, _, status = check({ 'docsSidebar' => ['expected-experience'] },
                                '[Setup](../DOCS/local.md#setup)', files) do |root|
        skip 'requires a case-insensitive filesystem' unless File.directory?(File.join(root, 'DOCS'))
        install_linked_file(root, mode)
      end
      refute_predicate status, :success?
      assert_includes output, '../DOCS/local.md#setup (missing file)'
    end
  end

  def test_publication_overrides_are_refused_in_front_matter
    { 'draft' => 'true', 'unlisted' => 'true', 'id' => 'renamed', 'slug' => '/shared',
      '<<' => '{id: renamed}' }.each do |key, value|
      page = "---\n#{key}: #{value}\n---\n# Guide\n"
      output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
      refute_predicate status, :success?
      assert_includes output, "expected-experience.md (#{key})"
    end
  end

  def test_ordinary_front_matter_remains_available
    page = "---\ntitle: Guide\nsidebar_position: 1\n---\n# Guide\n"
    output, errors, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end

  def test_empty_and_comment_only_front_matter_remain_available
    ['', '# note', 'null', '~'].each do |metadata|
      page = "---\n#{metadata}\n---\n# Guide\n"
      output, errors, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
      assert_predicate status, :success?, "#{output}\n#{errors}"
    end
  end

  def test_each_guide_needs_a_unique_publication_id
    %w[md mdx].each do |extension|
      output, errors, status = check({ 'docsSidebar' => %w[expected-experience install] }, '# Guide',
                                     "docs/install.#{extension}" => '# Install')
      assert_predicate status, :success?, "#{output}\n#{errors}"
    end
    files = { 'docs/install.md' => '# Install', 'docs/install.mdx' => '# Install' }
    output, _, status = check({ 'docsSidebar' => %w[expected-experience install] }, '# Guide', files)
    refute_predicate status, :success?
    assert_includes output, 'Duplicate publication IDs: install.md, install.mdx'
  end

  def test_numbered_source_names_are_refused_before_id_normalization
    ['01-install.md', '01-guides/install.md', '01.install.md', '01 - install.md'].each do |file|
      sidebar = { 'docsSidebar' => ['expected-experience', file.delete_suffix('.md')] }
      output, _, status = check(sidebar, '# Guide', "docs/#{file}" => '# Install')
      refute_predicate status, :success?
      assert_includes output, "Numbered source paths: #{file}"
    end
  end

  private

  def linked_fixture(mode)
    sidebar = { 'docsSidebar' => ['expected-experience'] }
    sidebar['docsSidebar'] << 'local' if mode == :tracked
    files = { '.gitignore' => "/docs/local.md\n", 'internal/target.md' => '# Setup' }
    check(sidebar, '[Setup](local.md#setup)', files) { |root| install_linked_file(root, mode) }
  end

  def install_linked_file(root, mode)
    path = File.join(root, 'docs/local.md')
    File.write(path, '# Setup') if %i[regular tracked].include?(mode)
    File.symlink('../internal/target.md', path) if mode == :alias
    system('git', '-C', root, 'add', '-f', 'docs/local.md', exception: true) if mode == :tracked
  end
end

class DocsGeneratedSourceTest < Minitest::Test
  include DocsNavigationFixture

  def test_overview_uses_the_filename_expected_by_site_preparation
    %w[md mdx].each do |extension|
      files = { "docs/README.#{extension}" => '# Overview' }
      output, _, status = check({ 'docsSidebar' => %w[expected-experience README] }, '# Guide', files)
      assert_equal extension == 'md', status.success?, output
      assert_includes output, 'Overview source must use README.md' if extension == 'mdx'
    end
  end

  def test_site_generated_changelog_cannot_overwrite_a_product_guide
    %w[md mdx].each do |extension|
      files = { "docs/changelog.#{extension}" => '# Unique product guide',
                'CHANGELOG.md' => '# Different release notes' }
      output, _, status = check({ 'docsSidebar' => %w[expected-experience changelog] }, '# Guide', files)
      refute_predicate status, :success?, output
      assert_includes output, "Site-generated path: changelog.#{extension}; edit CHANGELOG.md for release notes"
    end
  end
end

class DocsRouteSourceTest < Minitest::Test
  include DocsNavigationFixture

  def test_category_indexes_cannot_share_a_route
    %w[index README setup].combination(2) do |names|
      assert_collision(names.map { |name| "docs/setup/#{name}.md" })
    end
  end

  def test_parent_source_and_nested_index_cannot_share_a_route
    assert_collision(%w[docs/setup.md docs/setup/index.md])
  end

  def test_generated_sources_cannot_share_a_route_with_guides
    %w[docs/index.md docs/changelog/index.md docs/changelog/README.md].each { |path| assert_collision([path]) }
  end

  def test_independent_sources_keep_distinct_routes
    output, errors, status = source_result(%w[docs/setup/README.md docs/setup/guide.md docs/install.md])
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end

  def assert_collision(paths)
    output, _, status = source_result(paths)
    refute_predicate status, :success?, output
    assert_includes output, 'Sources share a site route:'
  end

  def source_result(paths)
    files = paths.to_h { |path| [path, '# Guide'] }
    ids = paths.map { |path| path.delete_prefix('docs/').delete_suffix('.md') }
    check({ 'docsSidebar' => ['expected-experience', *ids] }, '# Guide', files)
  end
end

class DocsLandingPolicyTest < Minitest::Test
  include DocsNavigationFixture

  def test_generated_category_landings_require_a_checked_source
    [{ 'type' => 'generated-index' }, { 'type' => 'generated-index', 'slug' => '/expected-experience' }].each do |link|
      sidebar = { 'docsSidebar' => [{ 'type' => 'category', 'label' => 'Start',
                                      'items' => ['expected-experience'], 'link' => link }] }
      _, errors, status = check(sidebar)
      refute_predicate status, :success?
      assert_includes errors, 'Category landings must name a checked doc'
    end
  end

  def test_explicit_category_landing_keeps_its_checked_source
    sidebar = { 'docsSidebar' => [{ 'type' => 'category', 'label' => 'Start', 'items' => ['expected-experience'],
                                    'link' => { 'type' => 'doc', 'id' => 'expected-experience' } }] }
    output, errors, status = check(sidebar)
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end

  def test_lowercase_tool_guides_keep_human_destinations
    %w[agents claude gemini skill].each do |name|
      files = { "docs/#{name}.md" => '# Human tool guide' }
      sidebar = { 'docsSidebar' => ['expected-experience', name] }
      output, errors, status = check(sidebar, "[Human](#{name}.md)", files)
      assert_predicate status, :success?, "#{output}\n#{errors}"
    end
  end
end
