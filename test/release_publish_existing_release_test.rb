# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/release_publish_fixture'

# A GitHub release that already exists counts as published only when it matches the approval.
class ReleasePublishExistingReleaseTest < Minitest::Test
  include ReleasePublishFixture

  def test_a_draft_or_unreadable_release_is_refused_before_publishing
    File.write(state('draft'), '')
    write_release([], 'Unrelated notes')
    assert_refused 'lacks the approved notes; delete it'
    write_release([], "Fixes things.\n")
    assert_refused 'is a draft with the approved notes; publish or delete it'
    File.write(state('gh_fails'), '')
    assert_refused 'Cannot read the GitHub release'
    assert_nil remote_tag
  end

  def test_an_existing_release_without_the_approved_notes_is_refused
    published_without_release
    ['Unrelated notes', "Fixes things.\n"].each do |body|
      write_release([], body)
      assert_refused 'lacks the approved notes'
    end
  end

  def test_an_existing_release_needs_the_right_flag_and_may_carry_generated_notes
    approved = published_without_release
    write_release(['--prerelease'], approved)
    assert_refused 'wrong prerelease flag'
    write_release([], "#{approved}\r\n\r\n## What's Changed\r\n")
    assert_empty publish
  end

  def test_approved_notes_with_windows_line_endings_match_either_form
    @approval = write_approval('1.2.0', notes_text: "Fixes things.\r\nAnd more.\r\n")
    push_annotated_tag(@commit)
    File.write(state('registry'), Digest::SHA256.file(@gem).hexdigest)
    ["Fixes things.\r\nAnd more.\r\n", "Fixes things.\nAnd more.\n"].each do |body|
      write_release([], body)
      assert_empty publish
    end
  end

  private

  # A skipped-gate approval whose tag and gem are published; returns its approved release text.
  def published_without_release
    @approval = write_approval('1.2.0', gate: { 'status' => 'skipped' })
    push_annotated_tag(@commit)
    File.write(state('registry'), Digest::SHA256.file(@gem).hexdigest)
    "Fixes things.\n\n#{ShakaRelease::Approval::SKIPPED_GATE}"
  end

  def write_release(args, body) = File.write(state('release'), JSON.generate('args' => args, 'body' => body))
end
