# frozen_string_literal: true

require_relative 'post_implementation_publication_test'
require 'shaka/post_implementation/evidence'

# The verification verdict is shown, read back for its head, and never blocks readiness.
class PostImplementationAdequacyTest < Minitest::Test
  include PostImplementationPublicationFixture

  Client = Struct.new(:issue_comments, :viewer_login)
  HEAD = 'a' * 40
  MARKER = Shaka::PostImplementationEvidence.adequacy('inadequate')

  def with_verdict(result, adequacy)
    report = JSON.parse(File.read(result['report'])).merge('verification_adequacy' => adequacy)
    File.write(result['report'], JSON.generate(report))
  end

  def comment(body, head: HEAD)
    { 'id' => 1, 'created_at' => '2026-10-01T00:00:00Z', 'user' => { 'login' => 'test-author' },
      'body' => "<!-- shaka:reply:post-implementation-#{head[0, 7]}-abc12345 -->\n#{body}" \
                "#{Shaka::PostImplementationEvidence.attestation(head, 'ready')}" }
  end

  def evidence(*comments) = Shaka::PostImplementationEvidence.new(Client.new(comments, 'test-author'))

  def test_inadequate_verification_is_shown_and_read_back_without_blocking_readiness
    with_result do |result, path|
      with_verdict(result, ADEQUACY.merge('verdict' => 'inadequate'))
      github, status = publish(result, path)
      assert_equal 0, status
      assert_includes github.bodies.first.first,
                      "**Verification:** Inadequate.\n\n- Weakest claim: #{ADEQUACY['weakest_claim']}"
      checkpoint = Shaka::PostImplementationEvidence.new(github)
      assert_equal %w[ready inadequate], checkpoint.call(HEAD).values_at('basis', 'verification_adequacy')
    end
  end

  def test_accepted_gaps_show_as_the_reviewers_judgment_and_keep_their_stored_marker
    with_result do |result, path|
      with_verdict(result, ADEQUACY.merge('verdict' => 'adequate with accepted gaps'))
      github, = publish(result, path)
      body = github.bodies.first.first
      assert_includes body, '**Verification:** Adequate, with gaps the reviewer judged acceptable.'
      refute_includes body, 'Adequate with accepted gaps'
      assert_includes body, '<!-- shaka:post-implementation-adequacy adequate_with_accepted_gaps -->'
      assert_equal 'adequate with accepted gaps', Shaka::PostImplementationEvidence.new(github).adequacy(HEAD)
    end
  end

  # The marker exactly as earlier comments carry it, spelled out so a rename here cannot pass by renaming both sides.
  def test_a_comment_published_with_the_earlier_label_still_parses
    published = comment("**Verification:** Adequate with accepted gaps.\n\n" \
                        "<!-- shaka:post-implementation-adequacy adequate_with_accepted_gaps -->\n")
    assert_equal 'adequate with accepted gaps', evidence(published).adequacy(HEAD)
  end

  def test_the_owner_disposition_keeps_the_verification_verdict_readable
    with_result do |result, path|
      with_verdict(result, ADEQUACY.merge('verdict' => 'adequate with accepted gaps'))
      disposition = { 'head' => HEAD, 'recommendation' => 'Merge', 'reason' => 'The checks reach the change.' }
      github, = publish(result.merge('disposition' => disposition), path)
      checkpoint = Shaka::PostImplementationEvidence.new(github)
      assert_equal ['Merge', 'adequate with accepted gaps'],
                   [checkpoint.recommendation(HEAD), checkpoint.adequacy(HEAD)]
    end
  end

  def test_a_verdict_planted_in_report_text_or_for_another_head_is_ignored
    planted = comment("#{MARKER}\nReport\n\n")
    assert_nil evidence(planted).call(HEAD)['verification_adequacy']
    assert_nil evidence(comment("Report\n\n#{MARKER}\n", head: 'b' * 40)).adequacy(HEAD)
    assert_equal 'inadequate', evidence(comment("Report\n\n#{MARKER}\n")).adequacy(HEAD)
  end

  def test_a_report_without_a_valid_verification_verdict_is_not_published
    with_result do |result, path|
      [nil, ADEQUACY.merge('verdict' => 'mostly'), ADEQUACY.merge('next_check' => "Two\nlines")].each do |adequacy|
        with_verdict(result, adequacy)
        assert_equal 1, publish(result, path)[1]
      end
    end
  end
end
