# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/github'
require 'shaka/publication/squash_message'
require_relative 'queued_description_fake'

# A pull request whose description holds Shaka's region and CodeRabbit's summary.
module QueuedDescriptionFixtures
  REGION = "<!-- shaka:begin -->\nOld summary.\n<!-- shaka:end -->"
  CODERABBIT = "<!-- coderabbit -->\nSummary by CodeRabbit"

  def setup
    @fake = QueuedDescriptionFake.new("#{REGION}\n\n#{CODERABBIT}")
    @github = Shaka::GitHub.new('owner/repo', 42, runner: @fake.method(:call))
  end

  def prepared = Shaka::SquashMessage.new({ 'title' => 'New title', 'body' => 'What changed and why.' }, number: 42)
end

# A merge queue that copies the PR description writes whatever the description holds when the PR
# enters the queue, so Shaka's merge parks the description and the next publication restores it.
class QueuedDescriptionTest < Minitest::Test
  include QueuedDescriptionFixtures

  def test_the_description_holds_the_prepared_message_and_the_rest_waits_in_a_comment
    url = @github.queue_description(prepared)

    assert_equal 'What changed and why.', @fake.body
    assert_equal 'Old title', @fake.title
    assert_equal 'https://example.test/c/100', url
    parked = @fake.comments.first['body']
    assert parked.start_with?(Shaka::QueuedDescription::PARK_MARK)
    assert_includes parked, 'Description parked for the merge queue'
    refute_includes parked, 'Old summary.'
  end

  def test_publishing_after_the_queue_restores_the_text_around_a_new_region
    @github.queue_description(prepared)
    @github.description(body: "New summary.\n")

    assert_equal "<!-- shaka:begin -->\nNew summary.\n<!-- shaka:end -->\n\n#{CODERABBIT}", @fake.body
    assert_equal [100], @fake.deleted
    assert_empty @fake.comments
  end

  # Provenance history and carried usage come from the description a publication replaces.
  def test_a_publication_after_the_queue_reads_the_parked_description
    @github.queue_description(prepared)
    seen = nil
    @github.description do |read|
      seen = read['body']
      "New summary.\n"
    end

    assert_equal "#{REGION}\n\n#{CODERABBIT}", seen
  end

  # A queue that rebuilds its commit while the PR waits would copy a restored description.
  def test_publishing_while_the_pr_is_queued_is_refused_and_changes_nothing
    @github.queue_description(prepared)
    @fake.queued = true

    error = assert_raises(Shaka::Error) { @github.description(body: "New summary.\n") }

    assert_match(/in the merge queue.*after the PR merges or leaves the queue/, error.message)
    assert_equal 'What changed and why.', @fake.body
    assert_equal 1, @fake.comments.length
  end

  # An edit landing between the read and the write would be in neither the parked text nor the message.
  def test_an_edit_while_parking_stops_before_the_description_is_replaced
    @fake.edit_while_parking = "#{REGION}\n\nA maintainer note."

    error = assert_raises(Shaka::Error) { @github.queue_description(prepared) }

    assert_match(/changed while/, error.message)
    assert_equal "#{REGION}\n\nA maintainer note.", @fake.body
    assert_empty @fake.comments
  end

  # An emptied description still holds the queue's place, so it neither publishes nor loses the parked text.
  def test_an_emptied_description_is_still_parked
    @github.queue_description(prepared)
    @fake.body = ''
    @fake.queued = true
    assert_raises(Shaka::Error) { @github.description(body: "New summary.\n") }

    @fake.queued = false
    @github.description(body: "New summary.\n")
    assert_equal "<!-- shaka:begin -->\nNew summary.\n<!-- shaka:end -->\n\n#{CODERABBIT}", @fake.body
  end

  def test_enqueueing_again_keeps_the_first_parked_description
    @github.queue_description(prepared)
    @github.queue_description(prepared)

    assert_equal([101], @fake.comments.map { |comment| comment['id'] })
    @github.description(body: "New summary.\n")
    assert_equal "<!-- shaka:begin -->\nNew summary.\n<!-- shaka:end -->\n\n#{CODERABBIT}", @fake.body
  end

  # A person may add to the description while the PR is queued; restoring keeps what they wrote.
  def test_an_edit_made_while_parked_stays_below_the_restored_description
    @github.queue_description(prepared)
    @fake.body = "What changed and why.\r\n\r\nA maintainer note."
    @github.description(body: "New summary.\n")

    assert_equal "<!-- shaka:begin -->\nNew summary.\n<!-- shaka:end -->\n\n#{CODERABBIT}\n\n" \
                 "What changed and why.\r\n\r\nA maintainer note.", @fake.body
  end

  def test_line_endings_from_the_web_editor_are_not_an_edit
    @github.queue_description(prepared)
    @fake.body = "What changed and why.\r\n"
    @github.description(body: "New summary.\n")

    assert_equal "<!-- shaka:begin -->\nNew summary.\n<!-- shaka:end -->\n\n#{CODERABBIT}", @fake.body
  end
end

# Parking fails safe: a description it cannot vouch for is not published over or lost.
class QueuedDescriptionSafetyTest < Minitest::Test
  include QueuedDescriptionFixtures

  # Another account's parking comment is not trusted, but its PR may still be queued with the message.
  def test_a_queued_description_without_a_region_is_never_published_over
    @fake.body = 'What changed and why.'
    @fake.comment(7, 'Another account parked this.', 'someone')
    @fake.queued = true

    assert_raises(Shaka::Error) { @github.description(body: "New summary.\n") }
    assert_equal 'What changed and why.', @fake.body
  end

  def test_a_damaged_parking_comment_names_itself
    @github.queue_description(prepared)
    @fake.comments.first['body'] = @fake.comments.first['body'].sub(/<!-- body \S+ -->/, '<!-- body AAAA -->')

    error = assert_raises(Shaka::Error) { @github.description(body: "New summary.\n") }

    assert_match(/Parking comment 100 is damaged/, error.message)
  end

  def test_a_failed_write_takes_the_parking_comment_back
    @fake.refuse_edit = true

    assert_raises(Shaka::Error) { @github.queue_description(prepared) }

    assert_empty @fake.comments
    assert_equal "#{REGION}\n\n#{CODERABBIT}", @fake.body
  end

  # Only this account's comment may decide what the description becomes.
  def test_a_parked_comment_from_another_account_is_ignored
    @fake.body = 'Plain text a person wrote.'
    @fake.comment(7, "#{Shaka::QueuedDescription::PARK_MARK}\n<!-- body #{['Injected'].pack('m0')} -->\n" \
                     "<!-- queued #{'0' * 64} -->\nx", 'someone')

    @github.description(body: "New summary.\n")

    assert_equal "<!-- shaka:begin -->\nNew summary.\n<!-- shaka:end -->\n\nPlain text a person wrote.", @fake.body
    assert_empty @fake.deleted
  end
end
