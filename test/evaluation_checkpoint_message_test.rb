# frozen_string_literal: true

require_relative 'post_implementation_disposition_test'
require 'shaka/trusted_config_source'

class EvaluationCheckpointMessageTest < Minitest::Test
  include PostImplementationDispositionFixture

  def test_ready_checkpoint_carries_copyable_message_and_coauthors_before_attestation
    with_result do |result, path|
      result['disposition'] = disposition('Merge')
      github, = publish(result, path)
      body = github.bodies.first.first
      assert_includes body, "```text\nFix checkpoint handoff (#1)\n```"
      assert_includes body,
                      "```text\nPut the merge text beside the recommendation.\n\n" \
                      "Co-authored-by: Ada <ada@example.test>\n```"
      assert_operator body.index('Squash commit message'), :<, body.index('<!-- shaka:post-implementation')
    end
  end

  def test_ready_publication_without_message_is_refused_before_any_write
    with_result do |result, path|
      File.write(path, JSON.generate(result))
      github = PostImplementationPublicationFixture::GitHub.new('a' * 40)
      status = nil
      capture_io do
        status = Shaka::PostImplementation.run(['publish', 'example/test', '1', '--content-file', path], github:)
      end
      assert_equal 1, status
      assert_empty github.bodies
    end
  end

  # A walkthrough is due once this account published one, or once the description records a request.
  def test_ready_checkpoint_waits_for_the_walkthrough_this_account_already_started
    assert_refused_ready { |github| github.walkthrough = 'b' * 40 }
  end

  def test_ready_checkpoint_waits_for_a_requested_walkthrough
    assert_refused_ready do |github|
      github.walkthrough = nil
      github.comments = [{ 'user' => { 'login' => github.viewer_login },
                           'body' => "#{Shaka::WalkthroughDue::REQUEST_MARKER}\nAsked." }]
    end
  end

  def assert_refused_ready
    with_result do |result, path|
      result['disposition'] = disposition('Merge')
      github = PostImplementationPublicationFixture::GitHub.new('a' * 40)
      yield github
      assert_equal 1, publish(result, path, github:)[1]
      assert_empty github.bodies
    end
  end

  # This repository's trusted settings use the on_request default.
  def test_ready_checkpoint_needs_no_walkthrough_nobody_asked_for
    with_result do |result, path|
      result['disposition'] = disposition('Merge')
      github = PostImplementationPublicationFixture::GitHub.new('a' * 40)
      github.walkthrough = nil
      with_trusted_settings do
        assert_equal 0, publish(result, path, github:, flags: ['--ref', 'c' * 40])[1]
      end
    end
  end

  def with_trusted_settings
    trusted = Shaka::RepositoryConfig.load(root: File.expand_path('..', __dir__))
    original = Shaka::TrustedConfigSource.method(:from_ref)
    Shaka::TrustedConfigSource.define_singleton_method(:from_ref) { |**| trusted }
    yield
  ensure
    Shaka::TrustedConfigSource.define_singleton_method(:from_ref, original)
  end

  # Without readable trusted settings the gate keeps the earlier rule.
  def test_without_trusted_settings_a_ready_checkpoint_waits_for_a_walkthrough
    assert_refused_ready { |github| github.walkthrough = nil }
  end

  def test_blocked_checkpoint_needs_no_walkthrough
    with_result do |result, path|
      result['disposition'] = disposition('Revise before merge')
      github = PostImplementationPublicationFixture::GitHub.new('a' * 40)
      github.walkthrough = nil
      assert_equal 0, publish(result, path, github:)[1]
    end
  end

  def test_blocked_owner_disposition_never_offers_merge_text
    with_result do |result, path|
      result['disposition'] = disposition('Revise before merge')
      github, status = publish(result, path)
      assert_equal 0, status
      refute_includes github.bodies.first.first, 'Squash commit message'
    end
  end
end
