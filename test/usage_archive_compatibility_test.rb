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

# Frozen reference format from a8cd8c4: one reference per record, each repeating the record.
module VersionTwoArchive
  module_function

  # The installed reader raises this from check_references, before its builder runs or anything is written.
  def reference(json)
    value = JSON.parse(json)
    unless value.is_a?(Hash) && value.keys.sort == %w[comments record sha256] && valid_reference?(value)
      raise Shaka::Error, 'Malformed usage archive reference.'
    end

    value
  end

  def valid_reference?(value)
    ids, digest, index = value.values_at('comments', 'sha256', 'record')
    valid_ids?(ids) && digest.is_a?(String) && digest.match?(/\A[0-9a-f]{64}\z/) &&
      index.is_a?(Integer) && index >= 0
  end

  def valid_ids?(ids)
    ids.is_a?(Array) && ids.size.between?(1, 128) && ids.all? { |id| id.is_a?(Integer) && id.positive? }
  end

  # What that writer published for these records, all archived in one set of comments.
  def body(original, github)
    blocks = Shaka::UsageRecords.parsed_blocks(original).map(&:first)
    payload = JSON.generate(blocks)
    ids = [payload].pack('m0').scan(Shaka::UsageArchive::CHUNKS).map { |chunk| upload(github, chunk) }
    refs = []
    compact = original.gsub(Shaka::UsageRecords::BLOCK) do |block|
      refs << { 'comments' => ids, 'sha256' => Digest::SHA256.hexdigest(payload), 'record' => blocks.index(block) }
      archived(block, refs.last)
    end
    guarded(compact, refs)
  end

  def archived(block, ref)
    links = ref['comments'].map.with_index { |id, index| "[part #{index + 1}](#issuecomment-#{id})" }.join(', ')
    inner = block.sub(/\A[^\n]*\n/, '').delete_suffix(Shaka::UsageRecords::END_MARK)
    "#{Shaka::UsageArchive::PREFIX}#{JSON.generate(ref)} -->\n#{inner}\n" \
      "Usage archive: #{links}. SHA256: `#{ref['sha256']}`.\n#{Shaka::UsageArchive::END_MARK}"
  end

  def upload(github, chunk)
    body = "🤖 AGENT · UNKNOWN · UNKNOWN · UNKNOWN\n\n#{Shaka::UsageArchive::HEADER}```base64\n#{chunk}\n```\n"
    github.api('repos/owner/repo/issues/42/comments', method: 'POST', fields: { body: })['id']
  end

  def guarded(compact, refs)
    entries = refs.map { |ref| ref.values_at('comments', 'sha256', 'record') }
    inventory = Digest::SHA256.hexdigest(JSON.generate(entries))
    compact.sub(Shaka::Publishing::OPEN_MARK) do |mark|
      "#{mark}#{Shaka::UsageArchiveReferences::INVENTORY_PREFIX}#{inventory} -->\n"
    end.sub(Shaka::Publishing::CLOSE_MARK, Shaka::Publishing::ARCHIVE_GUARD)
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

  def test_a_per_record_archive_is_restored_and_republished_without_new_uploads
    github = UsageArchiveTest::Comments.new
    original = mixed_body
    archived = VersionTwoArchive.body(original, github)
    archive = Shaka::UsageArchive.new(github)
    uploads = github.comments.size
    assert_equal original, archive.expand(archived)
    compact = archive.prepare(original).publish
    assert_equal uploads, github.comments.size, 'Republishing must reuse the existing archive comments.'
    assert_equal [%w[comments records sha256], %w[comments record sha256]], reference_shapes(compact)
  end

  def reference_shapes(body) = body.scan(Shaka::UsageArchive::REFERENCES).map { |json, _| JSON.parse(json).keys.sort }
  private :reference_shapes

  def test_the_per_record_reader_refuses_grouped_table_records_but_reads_reports_with_visible_text
    compact = Shaka::UsageArchive.new(UsageArchiveTest::Comments.new).prepare(mixed_body).publish
    native, legacy = compact.scan(Shaka::UsageArchive::REFERENCES).map(&:first)
    assert_raises(Shaka::Error) { VersionTwoArchive.reference(native) }
    assert_equal 1, VersionTwoArchive.reference(legacy)['record']
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
