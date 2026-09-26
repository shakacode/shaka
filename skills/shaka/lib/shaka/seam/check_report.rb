# frozen_string_literal: true

require 'json'

module Shaka
  class Seam
    # Labels seam-check JSON so candidate output cannot be cited as trusted policy.
    class CheckReport
      LOCAL_MODE = 'local/candidate'
      TRUSTED_MODE = 'trusted/ref'
      IMPLICIT_DIAGNOSTIC =
        'this check is local/candidate; it grants no policy or merge authority. ' \
        'Pass --local to make that explicit, or --ref SHA for trusted policy.'

      def self.local(config)
        new(config:, mode: LOCAL_MODE)
      end

      def self.trusted(config, ref:, writing_style: nil, warning: nil)
        new(config:, mode: TRUSTED_MODE, ref:, writing_style:, warning:)
      end

      def self.emit(payload)
        puts JSON.pretty_generate(payload)
        0
      end

      def initialize(config:, mode:, ref: nil, writing_style: nil, warning: nil)
        @config = config
        @mode = mode
        @ref = ref
        @writing_style = writing_style
        @warning = warning
      end

      def to_h
        payload = @config.to_h
        payload = payload.merge('writing_style' => @writing_style) if @writing_style
        payload = payload.merge('writing_style_warning' => @warning) if @warning
        payload.merge('validation' => validation)
      end

      private

      def validation
        payload = {
          'mode' => @mode,
          'grants_policy' => trusted?,
          'grants_merge_authority' => false
        }
        return payload unless trusted?

        payload.merge('ref' => @ref, 'sha' => @config.sha)
      end

      def trusted?
        @mode == TRUSTED_MODE
      end
    end
  end
end
