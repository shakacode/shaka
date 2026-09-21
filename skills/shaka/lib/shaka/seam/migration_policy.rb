# frozen_string_literal: true

require_relative '../error'

module Shaka
  class Seam
    # CLI review/merge flags fill missing policy and refuse to override from-ref values.
    module MigrationPolicy
      private

      def overlay_explicit_policy(classified)
        overlay_review(classified) if @options[:review_policy]
        overlay_merge(classified) if @options[:merge_preference]
        classified.blocking.delete('review.required') if classified.established.dig('review', 'required')
        classified.blocking.delete('merge.preference') if classified.established.dig('merge', 'preference')
      end

      def overlay_review(classified)
        require_review_flags!
        existing = classified.established['review'] || {}
        refuse_policy_override('--review-policy', 'review.required', existing['required'], @options[:review_policy])
        refuse_policy_override('--review-check', 'review.check', existing['check'], @options[:review_check])
        classified.established['review'] = existing.merge(review_overlay)
      end

      def require_review_flags!
        none = @options[:review_policy] == 'none'
        raise Error, '--review-check must be omitted when review policy is none' if none && @options.key?(:review_check)
        raise Error, '--review-check is required' if !none && !@options[:review_check]
      end

      def review_overlay
        overlay = { 'required' => @options[:review_policy] }
        overlay['check'] = @options[:review_check] if @options[:review_check]
        overlay
      end

      def overlay_merge(classified)
        existing = classified.established['merge'] || {}
        refuse_policy_override('--merge-preference', 'merge.preference', existing['preference'],
                               @options[:merge_preference])
        classified.established['merge'] = existing.merge('preference' => @options[:merge_preference])
      end

      def refuse_policy_override(flag, field, established, requested)
        return if established.nil? || requested.nil? || established == requested

        raise Error, "#{flag} contradicts #{field} established at from-ref"
      end
    end
  end
end
