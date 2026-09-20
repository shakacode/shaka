# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Two wait modes for optional review: swift merges on required checks, thorough waits.
  class ReviewPace
    VALUES = %w[swift thorough].freeze
    DEFAULT = 'swift'

    def self.normalize(value)
      return DEFAULT if value.nil?

      raise Error, 'review.pace must be swift or thorough' unless VALUES.include?(value)

      value
    end

    def self.effective(seam:, override: nil)
      paces = [normalize(seam)]
      paces << normalize(override) unless override.nil?
      paces.include?('thorough') ? 'thorough' : 'swift'
    end

    def self.seam_from_ref(root:, ref:)
      return unless ref

      require_relative 'trusted_config_source'
      TrustedConfigSource.load(root:, ref:).review.fetch('pace')
    end

    def self.allowed_merge_states(pace, queue_enabled)
      swift = normalize(pace) == 'swift'
      return %w[CLEAN BEHIND BLOCKED UNSTABLE] if queue_enabled && swift
      return %w[CLEAN BEHIND BLOCKED] if queue_enabled
      return %w[CLEAN UNSTABLE] if swift

      %w[CLEAN]
    end
  end
end
