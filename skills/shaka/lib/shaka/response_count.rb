# frozen_string_literal: true

module Shaka
  # Counts each native response once across sources; conflicting copies keep no usage.
  module ResponseCount
    private

    def count(record)
      identity = record['response_id']
      return @gaps << 'Unreadable or unidentifiable records' unless identity.is_a?(String) && !identity.empty?

      previous = @responses[identity]
      if previous && previous != record
        previous.merge!('usage' => {}, 'configuration' => [nil] * 4, 'timestamp' => nil, 'turn_id' => nil,
                        'billing_mode' => nil)
        @gaps << 'Conflicting response copies'
      end
      @responses[identity] ||= record
    end
  end
end
