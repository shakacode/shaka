# frozen_string_literal: true

module Shaka
  # Reads and verifies accounting comments through the same repository API.
  module UsageArchiveStorage
    private

    def identify_writer(body)
      @writer = Publishing.managed_region(body).to_s[/^🤖 [^\r\n]+$/] || '🤖 AGENT · UNKNOWN · UNKNOWN · UNKNOWN'
      @writer = @writer.split(ThroughputLine::SPEND, 2).first
    end

    def planned_references(blocks)
      raise Error, "Body exceeds GitHub's 65536-character limit; usage cannot make it fit." if blocks.empty?

      fresh = blocks.reject { |block| @references.key?(block) }
      return [@references, -> { @references }] if fresh.empty?

      chunks, digest = encode(fresh)
      placeholders = Array.new(chunks.size, 9_999_999_999_999_999_999)
      preview = @references.merge(reference_map(fresh, placeholders, digest))
      [preview, -> { store_references(fresh, chunks, digest) }]
    end

    def store_references(blocks, chunks, digest)
      ids = chunks.map { |chunk| write(chunk) }
      @references.merge!(reference_map(blocks, ids, digest))
    end

    def encode(blocks)
      raise Error, "Body exceeds GitHub's 65536-character limit; usage cannot make it fit." if blocks.empty?

      payload = JSON.generate(blocks)
      chunks = [payload].pack('m0').scan(UsageArchive::CHUNKS)
      raise Error, 'Usage archive exceeds 128 comment parts.' if chunks.size > 128

      [chunks, Digest::SHA256.hexdigest(payload)]
    end

    def read(reference)
      ids, digest = reference.values_at('comments', 'sha256')
      key = [ids, digest]
      return @read[key] if @read.key?(key)

      blocks = read_blocks(ids, digest)
      @references.merge!(reference_map(blocks, ids, digest))
      @read[key] = blocks
    end

    def read_blocks(ids, digest)
      payload = ids.map { |id| read_chunk(id) }.join.unpack1('m0')
      raise Error, 'Usage archive checksum changed; restore it before publishing.' unless
        Digest::SHA256.hexdigest(payload) == digest

      blocks = JSON.parse(payload)
      unless blocks.is_a?(Array) && blocks.all? { |block| valid_block?(block) }
        raise Error, 'Usage archive contains invalid accounting records.'
      end

      blocks
    end

    def valid_block?(block)
      block.is_a?(String) && UsageRecords::BLOCK.match(block)&.to_s == block &&
        UsageRecordShape.report_shape?(block) && UsageRecords.text_records(block).size == 1
    end

    def read_chunk(id)
      comment = @github.api("repos/#{@github.repository}/issues/comments/#{id}")
      path = URI.parse(comment.fetch('issue_url')).path
      encoded = comment.fetch('body')[UsageArchive::PAYLOAD, 1]
      unless path == "/repos/#{@github.repository}/issues/#{@github.number}" &&
             encoded && encoded.length <= UsageArchive::CHUNK_SIZE
        raise Error, 'Usage archive comment is changed or belongs to another PR.'
      end

      encoded
    end

    def write(chunk)
      body = "#{@writer}\n\n#{UsageArchive::HEADER}```base64\n#{chunk}\n```\n"
      comment = @github.api("repos/#{@github.repository}/issues/#{@github.number}/comments",
                            method: 'POST', fields: { body: })
      unless comment['body'] == body && comment['id'].is_a?(Integer) && comment['id'].positive?
        raise Error, 'Stored usage archive does not match; inspect the PR before retrying.'
      end

      comment['id']
    end
  end
end
