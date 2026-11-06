# frozen_string_literal: true

module Shaka
  # Reads and verifies accounting comments through the same repository API.
  module UsageArchiveStorage
    private

    def reference(json)
      value = JSON.parse(json)
      unless value.is_a?(Hash) && value.keys.sort == %w[comments record sha256] && valid_reference?(value)
        raise Error, 'Malformed usage archive reference.'
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

    def read(reference)
      ids, digest = reference.values_at('comments', 'sha256')
      key = [ids, digest]
      return @read[key] if @read.key?(key)

      blocks = read_blocks(ids, digest)
      @verified[digest] = ids
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
