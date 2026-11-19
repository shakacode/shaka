# frozen_string_literal: true

require_relative 'support/docs_navigation_fixture'

class DocsParserRegressionTest < Minitest::Test
  include DocsNavigationFixture

  AGENT_FORM_URL = 'https://github.com/shakacode/shaka/blob/main/skills/shaka/references/review.md'
  HUMAN_FORM_URL = 'https://github.com/shakacode/shaka/blob/main/docs/expected-experience.md'

  def test_static_form_destinations_receive_the_audience_check
    ['<form action="%s"><button>Review</button></form>',
     '<form><button formaction="%s">Review</button></form>',
     '<form><input type="submit" formaction="%s"></form>'].each do |markup|
      output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, format(markup, AGENT_FORM_URL))
      refute_predicate status, :success?, output
      assert_includes output, 'Link a human guide, not agent instructions:'

      output, errors, status = check({ 'docsSidebar' => ['expected-experience'] }, format(markup, HUMAN_FORM_URL))
      assert_predicate status, :success?, "#{output}\n#{errors}"
    end
  end

  def test_form_controls_use_only_their_navigation_attribute
    markup = '<form><button href="%<human>s" formaction="%<agent>s">Submit</button></form>'
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] },
                              format(markup, human: HUMAN_FORM_URL, agent: AGENT_FORM_URL))
    refute_predicate status, :success?, output
    assert_includes output, 'Link a human guide, not agent instructions:'
    page = format('<input type="text" formaction="%<url>s"><button type="button" formaction="%<url>s">Stay</button>',
                  url: AGENT_FORM_URL)
    output, errors, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end

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
      output, _, status = check_links("[Setup](#{target})")
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
  include DocsNavigationFixture

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

class DocsFootnotesTest < Minitest::Test
  include DocsNavigationFixture

  def test_footnote_text_is_not_a_link_destination
    page = "Text[^1]\n\n[^1]: Source.\n"
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    assert_predicate status, :success?, output
  end

  def test_rendered_links_inside_footnotes_get_the_audience_check
    page = "Text[^1]\n\n[^1]: [Agent](../skills/shaka/config/review-prompt.md)\n"
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    refute_predicate status, :success?
    assert_includes output, 'Link a human guide, not agent instructions:'
  end
end

class DocsUrlWhitespaceTest < Minitest::Test
  include DocsNavigationFixture

  def test_http_links_require_an_unambiguous_authority
    %w[http:/github.com http:github.com https:/github.com http:/example.com].each do |host|
      page = "<a href=\"#{host}/shakacode/shaka/blob/main/skills/shaka/references/review.md\">Review</a>"
      _, errors, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
      refute_predicate status, :success?
      assert_includes errors, 'HTTP(S) links must use ://host:'
    end
  end

  def test_extra_authority_slashes_keep_first_party_ownership
    %w[https://github.com https:////github.com ////github.com].each do |host|
      page = "<a href=\"#{host}/shakacode/shaka/blob/main/skills/shaka/references/review.md\">Review</a>"
      output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
      refute_predicate status, :success?
      assert_includes output, 'Link a human guide, not agent instructions:'
    end
    page = '<a href="https:////example.com/shakacode/shaka/blob/main/skills/shaka/references/review.md">Other</a>'
    output, errors, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end

  def test_html_backslashes_follow_browser_path_separators
    page = '<a href="https://github.com/shakacode/shaka\blob/main/skills/shaka/references/review.md">Review</a>'
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    refute_predicate status, :success?
    assert_includes output, 'Link a human guide, not agent instructions:'
  end

  def test_markdown_backslash_escape_remains_path_data
    page = '[Data](<https://github.com/shakacode/shaka\blob/main/skills/shaka/references/review.md>)'
    output, errors, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end

  def test_html_tilde_paths_do_not_lookup_local_users
    page = '<a href="~shaka-no-such-user/release-notes.html">Release notes</a>'
    output, errors, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end

  def test_encoded_markdown_tilde_paths_resolve_literal_files
    page = '[Guide](%7Eshaka-no-such-user.md)'
    files = { 'docs/~shaka-no-such-user.md' => '# Guide' }
    sidebar = { 'docsSidebar' => ['expected-experience', '~shaka-no-such-user'] }
    output, errors, status = check(sidebar, page, files)
    assert_predicate status, :success?, "#{output}\n#{errors}"
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    refute_predicate status, :success?
    assert_includes output, '(missing file)'
  end

  def test_html_url_whitespace_uses_browser_preprocessing
    pages = ['<a href="https://github.com/shakacode/shaka/blob/main/sk&#9;ills/shaka/references/review.md">Review</a>',
             '<a href="&#1;h&#13;ttps://github.com/shakacode/shaka/blob/main/' \
             'skills/shaka/references/review.md">Review</a>']
    pages.each do |page|
      output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
      refute_predicate status, :success?
      assert_includes output, 'Link a human guide, not agent instructions:'
    end
  end

  def test_encoded_tabs_and_markdown_renderer_escapes_remain_path_data
    pages = ['<a href="https://github.com/shakacode/shaka/blob/main/sk%09ills/shaka/references/review.md">Data</a>',
             "[Data](<https://github.com/shakacode/shaka/blob/main/sk\tills/shaka/references/review.md>)",
             '<a href="https://github.com/shakacode/shaka/blob/main/docs/se&#9;ttings.md">Settings</a>']
    pages.each do |page|
      output, errors, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
      assert_predicate status, :success?, "#{output}\n#{errors}"
    end
  end
end
