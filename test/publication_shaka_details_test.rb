# frozen_string_literal: true

require_relative 'publication_test'
require 'shaka/canary/body'

# Shaka metrics shows one cost line and one fold; the chat link leads it, and WIP Details closes it.
class PublicationShakaDetailsTest < Minitest::Test
  WIP = PublicationWipDetailsTest::WIP

  def render(wip)
    content = PublicationRegressionTest.new('render').description_content('wip' => wip, 'details' => [])
    Shaka::Publication.description(content)
  end

  # One fold holds all of Shaka's records, so the section shows one line and one disclosure.
  def test_wip_sits_inside_the_shaka_details_fold_where_handoff_still_reads_it
    rendered = render(WIP)
    fold = rendered.index("<details>\n<summary>🤙 Shaka details</summary>")
    refute_nil fold
    assert_operator fold, :<, rendered.index('<summary>WIP Details</summary>')
    # WIP Details is the fold's last block, so its close is followed at once by the fold's own.
    assert_match(%r{<summary>WIP Details</summary>\n\n(?:(?!</details>).)*\n\n</details>\n\n</details>}m, rendered)
    assert_equal rendered.scan('<details>').size, rendered.scan('</details>').size
    assert_wip_readable("#{Shaka::Publishing::OPEN_MARK}\n#{rendered}\n#{Shaka::Publishing::CLOSE_MARK}")
  end

  # Descriptions published before this layout keep WIP Details as a sibling of a fold named Details.
  def test_handoff_still_reads_a_description_in_the_earlier_layout
    note = Shaka::WipDetails.new(WIP).detail
    older = "## Shaka metrics\n\n<details>\n<summary>Details</summary>\n\nUsage.\n\n</details>\n\n" \
            "<details>\n<summary>#{note['summary']}</summary>\n\n#{note['body']}\n\n</details>"
    assert_wip_readable("#{Shaka::Publishing::OPEN_MARK}\n#{older}\n#{Shaka::Publishing::CLOSE_MARK}")
  end

  # Republishing a PR published in the earlier layout moves WIP Details into the fold, once.
  def test_republishing_an_earlier_layout_keeps_one_wip_note
    note = Shaka::WipDetails.new(WIP).detail
    older = "<details>\n<summary>Details</summary>\n\nUsage.\n\n</details>\n\n" \
            "<details>\n<summary>#{note['summary']}</summary>\n\n#{note['body']}\n\n</details>"
    body = "#{Shaka::Publishing::OPEN_MARK}\n#{older}\n#{Shaka::Publishing::CLOSE_MARK}"
    pull = { 'head' => { 'sha' => 'a' * 40 }, 'body' => body }
    content = PublicationRegressionTest.new('render').description_content('wip' => WIP, 'details' => [])
    rendered = Shaka::Publication.description(content, nil, pull)
    assert_equal 1, rendered.scan('<summary>WIP Details</summary>').size
    assert_equal 1, rendered.scan('<summary>🤙 Shaka details</summary>').size
    refute_includes rendered, '<summary>Details</summary>'
  end

  # Metadata carry reads the previous note through the same reader, so a link published in the new layout still
  # cannot silently become UNKNOWN for the same owner.
  def test_carry_reads_a_link_published_in_the_new_layout
    link = 'claude://claude.ai/epitaxy/local_5922e8bb-d78e-4daa-843d-fd8087cebde8'
    content = PublicationRegressionTest.new('render').description_content('wip' => WIP.merge('thread' => link),
                                                                          'details' => [])
    body = "#{Shaka::Publishing::OPEN_MARK}\n#{Shaka::Publication.description(content)}\n#{Shaka::Publishing::CLOSE_MARK}"
    pull = { 'head' => { 'sha' => 'a' * 40 }, 'body' => body }
    assert_equal link, Shaka::Handoff::WipNote.value(body, 'thread')
    error = assert_raises(Shaka::Error) do
      Shaka::Publication.description(content.merge('wip' => WIP), nil, pull)
    end
    assert_match(/chat link/i, error.message)
  end

  # The copy block sits in a fence, so the canary body check finds nothing new in it.
  def test_the_copy_block_adds_no_canary_issue
    link = 'codex://threads/1b4e28ba-2fa1-11d2-883f-0016d3cca427'
    assert_equal Shaka::Canary::BodyCheck.issues(render(WIP)),
                 Shaka::Canary::BodyCheck.issues(render(WIP.merge('thread' => link)))
  end

  def assert_wip_readable(body)
    assert_equal WIP['owner'], Shaka::Handoff::WipNote.value(body, 'owner')
    assert_equal WIP['revision'], Shaka::Handoff::WipNote.revision(body)
    assert_nil Shaka::Handoff::WipNote.problem(body)
  end

  # GitHub drops links to app addresses, so a code block's copy button is the one-click path.
  def test_an_available_chat_link_opens_the_fold_in_a_copyable_block
    link = 'claude://claude.ai/epitaxy/local_5922e8bb-d78e-4daa-843d-fd8087cebde8'
    rendered = render(WIP.merge('thread' => link))
    fold = "<details>\n<summary>🤙 Shaka details</summary>\n\n"
    assert_includes rendered, "#{fold}**Chat link on m5:**\n\n```text\n#{link}\n```\n\n"
    assert_includes rendered, "| Chat link | #{link} |"
  end

  # A chat opens only on the machine that holds it, so the label names the owner's machine when it is known.
  def test_the_chat_link_label_omits_an_unknown_machine
    link = 'codex://threads/1b4e28ba-2fa1-11d2-883f-0016d3cca427'
    [WIP.merge('owner' => 'UNKNOWN'), WIP.merge('owner' => 'UNKNOWN · Codex · k7q2')].each do |wip|
      assert_includes render(wip.merge('thread' => link)), "**Chat link:**\n\n```text\n#{link}\n```"
    end
  end

  # URI schemes are case-insensitive, so an uppercase one still gets the copy block.
  def test_an_uppercase_scheme_still_gets_the_copy_block
    link = 'CLAUDE://claude.ai/epitaxy/local_5922e8bb-d78e-4daa-843d-fd8087cebde8'
    assert_includes render(WIP.merge('thread' => link)), "```text\n#{link}\n```"
  end

  def test_a_codex_thread_gets_the_copy_block
    link = 'codex://threads/1b4e28ba-2fa1-11d2-883f-0016d3cca427'
    assert_includes render(WIP.merge('thread' => link)), "```text\n#{link}\n```"
  end

  # A body in the new layout republishes to the same layout, with one fold and one WIP note.
  def test_republishing_the_new_layout_keeps_one_fold_and_one_note
    content = PublicationRegressionTest.new('render').description_content('wip' => WIP, 'details' => [])
    first = Shaka::Publication.description(content)
    body = "#{Shaka::Publishing::OPEN_MARK}\n#{first}\n#{Shaka::Publishing::CLOSE_MARK}"
    again = Shaka::Publication.description(content, nil, { 'head' => { 'sha' => 'a' * 40 }, 'body' => body })
    assert_equal 1, again.scan('<summary>🤙 Shaka details</summary>').size
    assert_equal 1, again.scan('<summary>WIP Details</summary>').size
    assert_equal again.scan('<details>').size, again.scan('</details>').size
  end

  def test_no_chat_link_block_without_an_address_that_fits_one
    [WIP, WIP.merge('thread' => 'ask the owner'), WIP.merge('thread' => 'claude://a`b'),
     WIP.merge('thread' => 'claude://claude.ai/x</details>'),
     WIP.merge('thread' => 'codex://threads/example'), WIP.merge('thread' => 'claude://claude.ai/%ZZ'),
     WIP.merge('thread' => 'claude://claude.ai/a\b'), WIP.merge('thread' => 'claude://example.com/x'),
     WIP.merge('thread' => 'claude://claude.ai/EPITAXY/LOCAL_5922e8bb-d78e-4daa-843d-fd8087cebde8'),
     WIP.merge('thread' => 'claude://claude.ai/epitaxy/local_5922e8bb-d78e-4daa-843d-fd8087cebde8?x=a\b'),
     WIP.merge('thread' => 'codex://threads/1B4E28BA-2FA1-11D2-883F-0016D3CCA427'),
     WIP.merge('thread' => 'https://example.com/chat'), WIP.merge('thread' => 'vscode://file/x'), nil].each do |wip|
      refute_includes render(wip), '**Chat link'
    end
  end
end
