# frozen_string_literal: true

require_relative 'usage_archive_test'
require_relative 'description_usage_archive_test'

# Frozen merge boundary from 6ab1707. New archives must be refused by this older writer.
module LegacyDescriptionWriter
  OPEN = '<!-- shaka:begin -->'
  CLOSE = '<!-- shaka:end -->'

  def self.merge(existing, body)
    opens = existing.scan(OPEN).size
    closes = existing.scan(CLOSE).size
    unless opens == 1 && closes == 1 && existing.index(OPEN) < existing.index(CLOSE)
      raise Shaka::Error, 'The description has an ambiguous or malformed managed region; repair it before publishing.'
    end

    prefix, rest = existing.split(OPEN, 2)
    "#{prefix}#{OPEN}\n#{body}#{CLOSE}#{rest.split(CLOSE, 2).last}"
  end
end

# A format change must protect native records and older aggregate reports across versions.
class UsageArchiveCompatibilityTest < Minitest::Test
  include UsageRecordsFixture

  def mixed_body
    fields = DEFAULTS.merge('host' => 'claude-code', 'responses' => Array.new(6000) { |i| "response-#{i}" },
                            'columns' => [PublicationUsageTableTest::COLUMN],
                            'note' => 'Original pricing; UNKNOWN fees.')
    native = Shaka::UsageDetails.new('note' => 'Partial coverage.', 'records' => [fields]).detail.fetch('body')
    existing(native, record('codex', 'Legacy aggregate', responses: ['legacy-response'], contribution: 'review'))
  end

  def test_an_older_writer_refuses_before_replacing_archived_native_and_legacy_records
    github = UsageArchiveTest::Comments.new
    archive = Shaka::UsageArchive.new(github)
    original = mixed_body
    compact = archive.prepare(original).publish
    assert_raises(Shaka::Error) { LegacyDescriptionWriter.merge(compact, 'Fresh usage only.') }
    assert_equal original, archive.expand(compact)
    assert_equal 2, Shaka::UsageRecords.parsed_blocks(archive.expand(compact)).size
  end

  def test_repository_casing_does_not_make_a_same_pr_archive_unreadable
    github = UsageArchiveTest::Comments.new
    original = mixed_body
    compact = Shaka::UsageArchive.new(github).prepare(original).publish
    github.define_singleton_method(:repository) { 'Owner/Repo' }
    assert_equal original, Shaka::UsageArchive.new(github).expand(compact)
  end

  def test_a_new_writer_keeps_rejecting_unrelated_extra_markers
    github = DescriptionUsageArchiveTest::MemoryGitHub.new
    archive = Shaka::UsageArchive.new(github)
    github.stored['body'] = archive.prepare(mixed_body).publish + LegacyDescriptionWriter::OPEN
    before = github.stored['body']
    assert_raises(Shaka::Error) { github.description(body: 'Replacement.') }
    assert_equal before, github.stored['body']
  end

  def test_a_guard_without_archive_references_is_refused
    body = "#{Shaka::Publishing::OPEN_MARK}\nMissing references.\n#{Shaka::Publishing::ARCHIVE_GUARD}"
    archive = Shaka::UsageArchive.new(UsageArchiveTest::Comments.new)
    assert_raises(Shaka::Error) { archive.expand(body) }
  end

  def test_a_refresh_that_fits_keeps_raw_accounting_and_removes_the_guard
    github = DescriptionUsageArchiveTest::MemoryGitHub.new
    entry = record('codex', 'Original accounting', responses: Array.new(2500) { |i| "response-#{i}" })
    github.description(body: "#{entry}\n<!-- fixture metadata #{'x' * 30_000} -->\n")
    assert_includes github.stored['body'], Shaka::Publishing::ARCHIVE_GUARD
    github.description(body: "#{entry}\n")
    body = github.stored.fetch('body')
    refute_includes body, Shaka::Publishing::ARCHIVE_GUARD
    assert_includes body, entry
    assert_includes LegacyDescriptionWriter.merge(body, 'Replacement.'), 'Replacement.'
  end
end
