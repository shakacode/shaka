# frozen_string_literal: true

module Shaka
  # Keep native identities in local results. Public usage blocks keep the counters and attribution.
  module PublicUsageIdentity
    module_function

    def private?(pull) = pull.dig('base', 'repo', 'visibility') == 'private'

    def for_pull(body, pull)
      return body if private?(pull)

      redact(body)
    end

    def redact(body)
      raise Error, 'Publication contains an incomplete usage record.' if UsageRecords.unterminated(body).positive?

      body.gsub(UsageRecords::BLOCK) do |block|
        json = Regexp.last_match[1]
        identity = UsageRecords.parse(json)
        raise Error, 'Publication contains an invalid usage record.' unless identity

        withheld = JSON.parse(json)['identity_withheld'] == true
        block.sub(/\A[^\n]*/) { UsageRecords.begin_mark(without_ids(identity, withheld:)) }
      end
    end

    def without_ids(identity, withheld:)
      redacted = identity.merge('sources' => [], 'responses' => [])
      redacted['identity_withheld'] = true if withheld || identity['responses'].any?
      redacted
    end
  end
end
