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

class DocsParsedDocumentLinksTest < Minitest::Test
  include DocsNavigationFixture

  def document_link_check(extension, heading, page: "setup.#{extension}", target: "#{page}#install",
                          authority: 'github.com')
    host = authority.start_with?('//') ? authority : "https://#{authority}"
    files = { 'skills/shaka/guide.md' => "[Setup](#{host}/shakacode/shaka/blob/main/docs/#{target})" }
    files["docs/#{page}"] = heading if heading
    sidebar = ['expected-experience'] + (heading ? [page.sub(/\.mdx?\z/, '')] : [])
    check({ 'docsSidebar' => sidebar }, '# What to expect', files)
  end

  def test_protocol_relative_links_keep_the_literal_reference_guard
    %w[md mdx].product(%w[github.com example.com], [true, false]).each do |extension, authority, present|
      output, errors, status = document_link_check(extension, present ? '# Install' : '# Other',
                                                   authority: "//#{authority}")
      expected = present
      assert_equal expected, status.success?, "#{authority}/#{extension}/#{present}: #{output}\n#{errors}"
      assert_includes output, "docs/setup.#{extension}#install (missing anchor)" unless expected
    end
  end

  def test_literal_source_references_are_independent_of_scheme
    %w[file ftp git ssh git+https git+http].each do |scheme|
      guide = "[Source](#{scheme}://github.com/shakacode/shaka/blob/main/docs/settings.md#absent)"
      output, errors, status = check_links(guide)
      refute_predicate status, :success?, "#{scheme}: #{output}\n#{errors}"
    end
  end

  def test_emitted_markdown_and_mdx_pages_resolve
    %w[md mdx].each do |extension|
      output, errors, status = document_link_check(extension, '# Install')
      assert_predicate status, :success?, "#{output}\n#{errors}"
    end
  end

  def test_emitted_missing_pages_keep_the_exact_extension
    %w[md mdx].each do |extension|
      output, _, status = document_link_check(extension, nil)
      refute_predicate status, :success?, output
      assert_includes output, "docs/setup.#{extension}#install (missing file)"
    end
  end

  def test_emitted_mdx_anchors_are_checked
    %w[md mdx].each do |extension|
      output, _, status = document_link_check(extension, '# Other heading')
      refute_predicate status, :success?, output
      assert_includes output, "docs/setup.#{extension}#install (missing anchor)"
    end
  end

  def test_fenced_target_headings_are_not_anchors
    %w[md mdx].each do |extension|
      output, _, status = document_link_check(extension, "# Setup\n~~~text\n## Install\n~~~\n")
      refute_predicate status, :success?, output
      assert_includes output, "docs/setup.#{extension}#install (missing anchor)"
      output, errors, status = document_link_check(extension, "# Setup\n~~~text\n## Example\n~~~\n## Install\n")
      assert_predicate status, :success?, "#{output}\n#{errors}"
    end
  end

  def test_emitted_unicode_fragments_are_not_truncated
    output, errors, status = document_link_check('mdx', '# 日本語', target: 'setup.mdx#日本語')
    assert_predicate status, :success?, "#{output}\n#{errors}"
    output, _, status = document_link_check('mdx', '# Other heading', target: 'setup.mdx#日本語')
    refute_predicate status, :success?, output
    assert_includes output, 'docs/setup.mdx#%E6%97%A5%E6%9C%AC%E8%AA%9E (missing anchor)'
  end

  def test_emitted_non_markdown_assets_do_not_use_the_current_checkout
    %w[setup.mdx-backup#install img/historical.svg].each do |target|
      output, errors, status = document_link_check('mdx', '# Other heading', target: target)
      assert_predicate status, :success?, "#{output}\n#{errors}"
    end
  end

  def test_emitted_sentence_punctuation_does_not_hide_missing_pages
    %w[md mdx].each do |extension|
      page = "See https://github.com/shakacode/shaka/blob/main/docs/setup.#{extension}. More text"
      output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
      refute_predicate status, :success?, output
      assert_includes output, "docs/setup.#{extension} (missing file)"
    end
  end

  def test_emitted_paths_do_not_use_the_audience_heuristic
    page = 'examples/skills/shaka/references/guide.md'
    output, _, status = document_link_check('md', '# Other heading', page: page)
    refute_predicate status, :success?, output
    assert_includes output, "docs/#{page}#install (missing anchor)"
    output, errors, status = document_link_check('md', '# Install', page: page)
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end

  def test_emitted_default_port_preserves_anchor_validation
    %w[github.com github.com:443].each do |authority|
      output, _, status = document_link_check('md', '# Other heading', authority: authority)
      refute_predicate status, :success?, output
      assert_includes output, 'docs/setup.md#install (missing anchor)'
      output, errors, status = document_link_check('md', '# Install', authority: authority)
      assert_predicate status, :success?, "#{output}\n#{errors}"
    end
  end

  def test_literal_document_urls_in_code_examples_still_resolve
    page = "```ruby\nPAGE = 'https://github.com/shakacode/shaka/blob/main/docs/gone.md'\n```"
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    refute_predicate status, :success?, output
    assert_includes output, 'docs/gone.md (missing file)'
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

class DocsEmittedDelimiterTest < Minitest::Test
  include DocsNavigationFixture

  def test_pipe_delimiters_do_not_hide_missing_emitted_destinations
    %w[gone.md settings.md#absent settings.md#examples].product(%i[ruby table]).each do |target, kind|
      output, errors, status = check_links('# Guide', pipe_emitted_source(target, kind))
      expected = target == 'settings.md#examples'
      assert_equal expected, status.success?, "#{kind}/#{target}: #{output}\n#{errors}"
      assert_includes output, "-> docs/#{target} (missing" unless expected
    end
  end

  def pipe_emitted_source(target, kind)
    url = "https://github.com/shakacode/shaka/blob/main/docs/#{target}"
    text = kind == :ruby ? "PAGE = %q|#{url}|" : "|Guide|\n|---|\n|#{url}|\n"
    { "skills/shaka/guide.#{kind == :ruby ? 'rb' : 'md'}" => text }
  end
end

class DocsEmittedContextTest < Minitest::Test
  include DocsNavigationFixture

  def test_legacy_source_references_ignore_literal_delimiters
    ["'URL'", '"URL"', '%q{URL}', '%q[URL]', '%q|URL|'].product([true, false]).each do |literal, present|
      url = 'https://github.com/shakacode/shaka/blob/main/docs/settings.md#examples'
      source = "PAGE = #{literal.sub('URL', url)}"
      files = { 'skills/shaka/guide.rb' => source }
      files['docs/settings.md'] = '# Other' unless present
      output, errors, status = check_links('# Guide', files)
      assert_equal present, status.success?, "#{literal}/#{present}: #{output}\n#{errors}"
    end
  end

  def test_explicit_markdown_links_preserve_fragment_data
    %w[_ * ~ ? ! :].each do |suffix|
      fragment = "setup#{suffix}"
      files = { 'docs/settings.md' => "# Guide\n<a id=\"#{fragment}\"></a>" }
      page = "[Setup](settings.md##{fragment})"
      output, errors, status = check_links(page, files)
      assert_predicate status, :success?, "#{fragment}: #{output}\n#{errors}"
    end
  end

  def test_shorter_anchor_cannot_credit_a_literal_fragment
    page = '[Setup](settings.md#setup_)'
    output, _, status = check_links(page, 'docs/settings.md' => '# Setup')
    refute_predicate status, :success?, output
    assert_includes output, '#setup_ (missing anchor)'
  end

  def test_markdown_context_distinguishes_bare_links_from_literal_code
    url = 'https://github.com/shakacode/shaka/blob/main/docs/settings.md#setup_'
    { url => false, "[Setup](#{url})" => true, "<#{url}>" => true,
      "`#{url}`" => true, "```ruby\nPAGE = %q{#{url}}\n```" => true }.each do |page, expected|
      output, errors, status = check_links(page, 'docs/settings.md' => '# Setup_')
      assert_equal expected, status.success?, "#{page}: #{output}\n#{errors}"
    end
  end

  def test_literal_source_guard_still_checks_unused_document_references
    page = "# Guide\n\n[unused]: https://github.com/shakacode/shaka/blob/main/docs/gone.md\n"
    output, errors, status = check_links(page)
    refute_predicate status, :success?, "#{output}\n#{errors}"
  end
end

class DocsEmittedValuesTest < Minitest::Test
  include DocsNavigationFixture

  def test_legacy_source_references_cover_common_yaml_text
    url = 'https://github.com/shakacode/shaka/blob/main/docs/settings.md#setup_'
    ["url: '#{url}'\n", "guide: '[Setup](#{url})'\n", "guide: |\n  [Setup](#{url})\n"].each do |yaml|
      files = { 'docs/settings.md' => '# Setup_', 'skills/shaka/config/guide.yml' => yaml }
      output, errors, status = check_links('# Guide', files)
      assert_predicate status, :success?, "#{yaml}: #{output}\n#{errors}"
    end
  end

  def test_source_reference_cannot_use_a_shorter_heading
    files = { 'docs/settings.md' => '# Setup', 'skills/shaka/config/guide.yml' =>
              "url: 'https://github.com/shakacode/shaka/blob/main/docs/settings.md#setup_'\n" }
    output, _, status = check_links('# Guide', files)
    refute_predicate status, :success?, output
    assert_includes output, '#setup_ (missing anchor)'
  end

  def test_source_references_keep_target_ids_in_prose
    %w[examples absent].each do |fragment|
      source = "GUIDE = 'Read [setup](https://github.com/shakacode/shaka/blob/main/docs/settings.md##{fragment}).'"
      output, errors, status = check_links('# Guide', 'skills/shaka/guide.rb' => source)
      assert_equal fragment == 'examples', status.success?, "#{output}\n#{errors}"
    end
  end
end

class DocsEmittedFallbackTest < Minitest::Test
  include DocsNavigationFixture

  def test_protocol_relative_markdown_destinations_keep_anchor_validation
    %w[examples absent].each do |fragment|
      page = "[Setup](//github.com/shakacode/shaka/blob/main/docs/settings.md##{fragment})"
      output, errors, status = check_links(page)
      assert_equal fragment == 'examples', status.success?, "#{output}\n#{errors}"
    end
  end

  def test_shell_pipe_is_a_literal_url_separator
    %w[settings.md#examples gone.md].each do |target|
      page = "```bash\ncurl https://github.com/shakacode/shaka/blob/main/docs/#{target}|cat\n```"
      output, errors, status = check_links(page)
      assert_equal target.start_with?('settings'), status.success?, "#{output}\n#{errors}"
    end
  end

  def test_json_literals_do_not_gain_markdown_delimiters
    %w[examples absent].each do |fragment|
      source = %({"url":"https://github.com/shakacode/shaka/blob/main/docs/settings.md##{fragment}"})
      output, errors, status = check_links('# Guide', 'skills/shaka/guide.json' => source)
      assert_equal fragment == 'examples', status.success?, "#{output}\n#{errors}"
    end
  end
end

class DocsEmittedLiteralGroupTest < Minitest::Test
  include DocsNavigationFixture

  def test_multiline_source_references_keep_the_legacy_guard
    %w[examples absent].product([true, false]).each do |fragment, used|
      use = used ? 'Read [Setup][setup].' : 'No rendered link.'
      source = "GUIDE = <<~MARKDOWN\n  #{use}\n\n  [setup]: " \
               "https://github.com/shakacode/shaka/blob/main/docs/settings.md##{fragment}\nMARKDOWN\n"
      output, errors, status = check_links('# Guide', 'skills/shaka/guide.rb' => source)
      assert_equal fragment == 'examples', status.success?, "#{fragment}/#{used}: #{output}\n#{errors}"
    end
  end

  def test_malformed_non_github_tokens_do_not_abort_other_targets
    [false, true].each do |missing|
      source = 'http:/// https://?x'
      source += ' https://github.com/shakacode/shaka/blob/main/docs/gone.md' if missing
      output, errors, status = check_links('# Guide', 'skills/shaka/guide.txt' => source)
      assert_equal !missing, status.success?, "#{output}\n#{errors}"
      assert_includes output, 'guide.txt -> docs/gone.md (missing file)' if missing
    end
  end
end

class DocsLegacyTextReferencesTest < Minitest::Test
  include DocsNavigationFixture

  def test_external_links_without_the_source_namespace_are_not_checked
    output, errors, status = check_links('[Guide](https://example.com/guide.md#absent)')
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end

  def test_literal_references_are_checked_outside_markdown_links
    reference = 'shakacode/shaka/blob/main/docs/gone.md'
    ["Plain: #{reference}", "---\nsource: #{reference}\n---\n# Guide", "<!-- #{reference} -->"].each do |source|
      output, errors, status = check_links('# Guide', 'skills/shaka/guide.md' => source)
      refute_predicate status, :success?, "#{output}\n#{errors}"
      assert_includes output, 'guide.md -> docs/gone.md (missing file)'
    end
  end
end

class DocsParsedReferencePrecedenceTest < Minitest::Test
  include DocsNavigationFixture

  def test_encoded_destinations_win_in_inline_reference_and_html_links
    url = 'https://github.com/shakacode/shaka/blob/main/docs/settings.md#install%2Dguide'
    pages = ["日本語 [Guide](#{url}) [Again](#{url})", "[Guide][ref]\n\n[ref]: #{url}",
             '<a href="https://github.com/shakacode/shaka/blob/main/docs/settings.md#install&#45;guide">Guide</a>']
    pages.each do |page|
      output, errors, status = check_links(page, 'docs/settings.md' => '# Install guide')
      assert_predicate status, :success?, "#{page}: #{output}\n#{errors}"
    end
  end

  def test_plain_reference_to_the_same_page_is_not_masked_by_a_valid_link
    page = '[Guide](https://github.com/shakacode/shaka/blob/main/docs/settings.md#install%2Dguide)' \
           "\n\nPlain: shakacode/shaka/blob/main/docs/settings.md#absent"
    output, _, status = check_links(page, 'docs/settings.md' => '# Install guide')
    refute_predicate status, :success?, output
    assert_includes output, '#absent (missing anchor)'
    refute_includes output, '#install (missing anchor)'
  end

  def test_rendered_non_markdown_assets_do_not_require_a_markdown_prefix_file
    page = '[Asset](https://github.com/shakacode/shaka/blob/main/docs/setup.mdx-backup)'
    output, errors, status = check_links(page)
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end

  REFERENCE_LABEL_PAGE = <<~MARKDOWN
    [Setup][shakacode/shaka/blob/main/docs/gone.md]

    [shakacode/shaka/blob/main/docs/gone.md]: https://github.com/shakacode/shaka/blob/main/docs/settings.md
  MARKDOWN

  def test_reference_labels_keep_the_literal_source_guard
    sidebar = %w[expected-experience settings]
    [false, true].each do |present|
      files = present ? { 'docs/gone.md' => '# Present' } : {}
      navigation = { 'docsSidebar' => present ? sidebar + ['gone'] : sidebar }
      output, errors, status = check(navigation, REFERENCE_LABEL_PAGE,
                                     { 'docs/settings.md' => SETTINGS }.merge(files))
      assert_equal present, status.success?, "#{output}\n#{errors}"
      assert_includes output, 'docs/gone.md (missing file)' unless present
    end
  end

  def test_literal_dot_segments_use_canonical_inventory_paths
    files = { 'README.md' => '# Project', 'skills/shaka/guide.rb' =>
              "PAGE = 'https://github.com/shakacode/shaka/blob/main/docs/../README.md'" }
    output, errors, status = check_links('# Guide', files)
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end

  def test_historical_destinations_do_not_use_current_checkout_headings
    %w[1234567890abcdef1234567890abcdef12345678 v1.0].each do |ref|
      page = "[Guide](https://github.com/shakacode/shaka/blob/#{ref}/docs/settings.md#日本語)"
      output, errors, status = check_links(page, 'docs/settings.md' => '# Renamed')
      assert_predicate status, :success?, "#{output}\n#{errors}"
    end
  end

  def test_main_destinations_follow_current_checkout_headings
    page = '[Guide](https://github.com/shakacode/shaka/blob/main/docs/settings.md#日本語)'
    ['# 日本語', '# Renamed'].each do |heading|
      output, errors, status = check_links(page, 'docs/settings.md' => heading)
      assert_equal heading == '# 日本語', status.success?, "#{output}\n#{errors}"
    end
  end

  def test_bare_link_punctuation_does_not_restore_the_literal_guard
    cases = [['1234567890abcdef1234567890abcdef12345678', '# Renamed', true],
             ['main', '# Renamed', false], ['main', '# Setup', true]]
    cases.each do |ref, heading, expected|
      page = "https://github.com/shakacode/shaka/blob/#{ref}/docs/settings.md#setup_."
      output, errors, status = check_links(page, 'docs/settings.md' => heading)
      assert_equal expected, status.success?, "#{output}\n#{errors}"
    end
  end
end
