# frozen_string_literal: true

module Shaka
  class Handoff
    # Turns the workflow-name readiness report into the Ask handoff fact.
    module WorkflowNames
      UNVERIFIED = 'workflow names unverified'

      module_function

      def fact(report)
        return unless report.is_a?(Hash)

        missing = Array(report['missing'])
        pending = Array(report['unverified'])
        return UNVERIFIED if missing.empty? && pending.empty? && report['status'] == 'unverified'
        return if missing.empty? && pending.empty?

        parts(missing, pending)
      end

      def note(text)
        return 'Workflow secret and variable names could not be verified.' if text == UNVERIFIED

        "Name #{text} in the Ask handoff."
      end

      def parts(missing, pending)
        listed = []
        listed << "missing workflow names #{missing.join(', ')}" if missing.any?
        listed << "unverified workflow names #{pending.join(', ')}" if pending.any?
        listed.join('; ')
      end
      private_class_method :parts
    end
  end
end
