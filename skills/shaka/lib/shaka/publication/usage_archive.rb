# frozen_string_literal: true

require 'digest'
require 'json'
require 'uri'
require_relative '../usage/usage_records'
require_relative 'usage_archive_storage'

module Shaka
  # Keeps accounting bytes in same-PR comments when usage outgrows a description.
  class UsageArchive
    include UsageArchiveStorage

    LIMIT = 65_536
    CHUNK_SIZE = 48_000
    PREFIX = '<!-- shaka:usage-archive '
    END_MARK = '<!-- shaka:usage-archive:end -->'
    REFERENCES = /#{Regexp.escape(PREFIX)}([^\n]*) -->\n(.*?)#{Regexp.escape(END_MARK)}/m
    HEADER = 'Usage accounting archive. ' \
             "Keep this comment: later description updates verify its checksum.\n\n"
    PAYLOAD = %r{\A🤖 [^\r\n]+\n\n#{Regexp.escape(HEADER)}```base64\n([A-Za-z0-9+/=]+)\n```\n\z}
    CHUNKS = /.{1,#{CHUNK_SIZE}}/o

    Plan = Struct.new(:preview, :writer) do
      def publish = writer.call
    end

    def initialize(github)
      @github = github
      @verified = {}
    end

    # Planning checks the final size without writing comments. Rendering and the
    # original body/head check must succeed before the caller publishes this plan.
    def prepare(body)
      return Plan.new(body, -> { body }) if body.length <= LIMIT

      identify_writer(body)
      blocks = records(body)
      chunks, digest = encode(blocks)
      ids = @verified[digest] || Array.new(chunks.size, 9_999_999_999_999_999_999)
      preview = replace(body, blocks, ids, digest)
      check_preview(preview)
      Plan.new(preview, -> { replace(body, blocks, archive_ids(chunks, digest), digest) })
    end

    # Restore before carry/deduplication. Comments are mutable; a link alone is
    # never accounting evidence. Reading is restricted to this PR's API comments.
    def expand(body)
      @read = {}
      region = archive_region(body)
      return body unless region&.include?(PREFIX)

      check_references(region)
      expanded = region.gsub(REFERENCES) do
        restore(Regexp.last_match[1], Regexp.last_match[2])
      end
      Publishing.without_archive_guard(replace_region(body, region, expanded))
    rescue IndexError, JSON::ParserError, ArgumentError
      raise Error, 'Usage archive is missing or malformed; restore it before publishing.'
    end

    private

    def archive_region(body)
      region = Publishing.managed_region(body)
      if body.include?(Publishing::ARCHIVE_GUARD) && !region&.include?(PREFIX)
        raise Error, 'Usage archive references are missing or malformed; restore them before publishing.'
      end

      region
    end

    def check_preview(preview)
      raise Error, 'Body exceeds GitHub\'s 65536-character limit after archiving usage.' if preview.length > LIMIT
    end

    def check_references(region)
      return if region.scan(REFERENCES).size == region.scan(PREFIX).size

      raise Error, 'Malformed usage archive reference.'
    end

    def archive_ids(chunks, digest) = @verified[digest] ||= chunks.map { |chunk| write(chunk) }

    def restore(json, visible)
      ref = reference(json)
      block = read(ref).fetch(ref.fetch('record'))
      raise Error, 'Archived usage display changed; restore it before publishing.' unless display(block, ref) == visible

      block
    end

    def records(body)
      region = Publishing.managed_region(body)
      return [] unless region

      UsageRecords.parsed_blocks(region).filter_map do |block, fields|
        block if fields && UsageRecordShape.report_shape?(block)
      end.uniq
    end

    def inner(block) = block.sub(/\A[^\n]*\n/, '').delete_suffix(UsageRecords::END_MARK)

    def replace(body, blocks, ids, digest)
      region = Publishing.managed_region(body)
      compact = region.gsub(UsageRecords::BLOCK) do |block|
        index = blocks.index(block)
        next block unless index

        ref = { 'comments' => ids, 'sha256' => digest, 'record' => index }
        "#{PREFIX}#{JSON.generate(ref)} -->\n#{display(block, ref)}#{END_MARK}"
      end
      Publishing.with_archive_guard(replace_region(body, region, compact))
    end

    def replace_region(body, region, replacement)
      body.sub("#{Publishing::OPEN_MARK}#{region}#{Publishing::CLOSE_MARK}") do
        "#{Publishing::OPEN_MARK}#{replacement}#{Publishing::CLOSE_MARK}"
      end
    end

    def display(block, ref)
      links = ref.fetch('comments').map.with_index do |id, index|
        "[part #{index + 1}](#issuecomment-#{id})"
      end.join(', ')
      "#{inner(block)}\nUsage archive: #{links}. SHA256: `#{ref.fetch('sha256')}`.\n"
    end
  end
end
