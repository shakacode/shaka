# frozen_string_literal: true

require_relative 'support/docs_navigation_fixture'

class DocsNavigationTest < Minitest::Test
  include DocsNavigationFixture

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

class DocsEmittedLinksTest < Minitest::Test
  include DocsNavigationFixture

  def emitted_page_check(extension, heading, page: "setup.#{extension}", target: "#{page}#install")
    files = { 'skills/shaka/guide.rb' => "PAGE = 'https://github.com/shakacode/shaka/blob/main/docs/#{target}'" }
    files["docs/#{page}"] = heading if heading
    sidebar = ['expected-experience'] + (heading ? [page.sub(/\.mdx?\z/, '')] : [])
    check({ 'docsSidebar' => sidebar }, '# What to expect', files)
  end

  def test_emitted_markdown_and_mdx_pages_resolve
    %w[md mdx].each do |extension|
      output, errors, status = emitted_page_check(extension, '# Install')
      assert_predicate status, :success?, "#{output}\n#{errors}"
    end
  end

  def test_emitted_missing_pages_keep_the_exact_extension
    %w[md mdx].each do |extension|
      output, _, status = emitted_page_check(extension, nil)
      refute_predicate status, :success?, output
      assert_includes output, "docs/setup.#{extension}#install (missing file)"
    end
  end

  def test_emitted_mdx_anchors_are_checked
    %w[md mdx].each do |extension|
      output, _, status = emitted_page_check(extension, '# Other heading')
      refute_predicate status, :success?, output
      assert_includes output, "docs/setup.#{extension}#install (missing anchor)"
    end
  end

  def test_emitted_unicode_fragments_are_not_truncated
    output, errors, status = emitted_page_check('mdx', '# 日本語', target: 'setup.mdx#日本語')
    assert_predicate status, :success?, "#{output}\n#{errors}"
    output, _, status = emitted_page_check('mdx', '# Other heading', target: 'setup.mdx#日本語')
    refute_predicate status, :success?, output
    assert_includes output, 'docs/setup.mdx#%E6%97%A5%E6%9C%AC%E8%AA%9E (missing anchor)'
  end

  def test_emitted_path_suffixes_are_not_credited_as_mdx
    output, _, status = emitted_page_check('mdx', '# Install', target: 'setup.mdx-backup#install')
    refute_predicate status, :success?, output
    assert_includes output, 'docs/setup.mdx-backup#install (missing file)'
  end

  def test_emitted_sentence_punctuation_does_not_hide_missing_pages
    %w[md mdx].each do |extension|
      output, _, status = emitted_page_check(extension, nil, target: "setup.#{extension}. More text")
      refute_predicate status, :success?, output
      assert_includes output, "docs/setup.#{extension} (missing file)"
    end
  end

  def test_emitted_paths_do_not_use_the_audience_heuristic
    page = 'examples/skills/shaka/references/guide.md'
    output, _, status = emitted_page_check('md', '# Other heading', page: page)
    refute_predicate status, :success?, output
    assert_includes output, "docs/#{page}#install (missing anchor)"
    output, errors, status = emitted_page_check('md', '# Install', page: page)
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end
end

class DocsSidebarAudienceTest < Minitest::Test
  include DocsNavigationFixture

  def test_sidebar_metadata_is_not_navigation
    [42, '../skills/shaka/references/review.md'].each do |value|
      item = { 'type' => 'doc', 'id' => 'expected-experience', 'customProps' => { 'href' => value } }
      output, _, status = check('docsSidebar' => [item])
      assert_predicate status, :success?, output
    end
  end

  def test_nested_sidebar_links_are_checked_while_metadata_is_ignored
    link = { 'type' => 'link', 'label' => 'Review', 'href' => '../skills/shaka/references/review.md' }
    category = { 'type' => 'category', 'label' => 'Guides', 'customProps' => { 'href' => 42 }, 'items' => [link] }
    output, _, status = check('docsSidebar' => ['expected-experience', category])
    refute_predicate status, :success?
    assert_includes output, 'sidebars.json -> ../skills/shaka/references/review.md'
  end
end

class DocsSidebarReferencesTest < Minitest::Test
  include DocsNavigationFixture

  def test_sidebar_collections_require_arrays
    [false, true].each do |array|
      collection_sidebars(array).each do |sidebar|
        output, errors, status = check(sidebar)
        assert_equal array, status.success?, "#{output}\n#{errors}"
        assert_includes errors, 'Expected sidebar items array' unless array
      end
    end
  end

  def collection_sidebars(array)
    collection = array ? ['expected-experience'] : 'expected-experience'
    category = { 'type' => 'category', 'label' => 'Guides', 'items' => collection }
    [{ 'docsSidebar' => ['expected-experience'], 'otherSidebar' => collection }, { 'docsSidebar' => [category] }]
  end

  def test_secondary_sidebar_document_references_must_exist
    %w[deleted-guide expected-experience].each do |id|
      sidebar = { 'docsSidebar' => ['expected-experience'], 'otherSidebar' => [{ 'type' => 'doc', 'id' => id }] }
      output, errors, status = check(sidebar)
      assert_equal id == 'expected-experience', status.success?, "#{output}\n#{errors}"
      assert_includes output, 'Navigation targets missing pages: deleted-guide' if id == 'deleted-guide'
    end
  end

  def test_category_landing_document_references_must_exist
    %w[deleted-guide expected-experience].each do |id|
      category = { 'type' => 'category', 'label' => 'Guides', 'items' => ['expected-experience'],
                   'link' => { 'type' => 'doc', 'id' => id } }
      output, errors, status = check('docsSidebar' => [category])
      assert_equal id == 'expected-experience', status.success?, "#{output}\n#{errors}"
      assert_includes output, 'Navigation targets missing pages: deleted-guide' if id == 'deleted-guide'
    end
  end

  def test_category_landing_document_counts_as_primary_enrollment
    category = { 'type' => 'category', 'label' => 'Guide', 'items' => [],
                 'link' => { 'type' => 'doc', 'id' => 'expected-experience' } }
    output, errors, status = check('docsSidebar' => [category])
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end
end

class DocsSidebarInventoryTest < Minitest::Test
  include DocsNavigationFixture

  def test_ignored_sidebar_cannot_replace_a_deleted_tracked_manifest
    clean = nil
    files = { '.gitignore' => "/docs/sidebars.json\n" }
    dirty = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', files) do |root|
      delete_tracked_manifest(root)
      File.unlink(File.join(root, 'docs/sidebars.json'))
      clean = Open3.capture3('ruby', File.expand_path('../bin/check-docs-navigation', __dir__), File.join(root, 'docs'))
      File.write(File.join(root, 'docs/sidebars.json'), '{"docsSidebar":["expected-experience"]}')
    end
    [dirty, clean].each { |result| assert_missing_manifest(result) }
  end

  private

  def assert_missing_manifest(result)
    _output, errors, status = result
    refute_predicate status, :success?
    assert_includes errors, 'Sidebar must be in the checked inventory: docs/sidebars.json'
  end

  def delete_tracked_manifest(root)
    system('git', '-C', root, 'add', '.', exception: true)
    system('git', '-C', root, 'add', '-f', 'docs/sidebars.json', exception: true)
    commit_fixture(root)
    system('git', '-C', root, 'rm', '--cached', '-q', 'docs/sidebars.json', exception: true)
    commit_fixture(root)
  end

  def commit_fixture(root)
    args = %w[-c user.name=TestUser -c user.email=test@example.com -c commit.gpgsign=false]
    system('git', '-C', root, *args, 'commit', '--no-verify', '-qm', 'Manifest fixture', exception: true)
  end
end
