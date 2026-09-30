# frozen_string_literal: true

module Shaka
  class WorkflowConfiguration
    # Decides whether one referenced name is present, missing, or unverified.
    class Verdict
      def initialize(kind, catalog)
        @kind = kind
        @catalog = catalog
      end

      def divide(names, repo_state:, org_state:, entries:, access:)
        @repo_state = repo_state
        @org_state = org_state
        @entries = entries
        @access = access
        @missing = []
        @pending = []
        names.each { |name| place(name) }
        [@missing, @pending]
      end

      private

      def place(name)
        case judge(name)
        when :missing then @missing << "#{@kind}.#{name}"
        when :present then nil
        else @pending << "#{@kind}.#{name}"
        end
      end

      def judge(name)
        visible = org_visibility(name)
        return visible if visible
        return :unverified if @repo_state != :ok || %i[denied truncated].include?(@org_state)
        return :missing if %i[skipped ok].include?(@org_state)

        :unverified
      end

      def org_visibility(name)
        return unless @org_state == :ok

        entry = @entries.find { |item| item['name'] == name }
        return unless entry

        case @catalog.visible(entry, @access, @kind)
        when true then :present
        when nil then :unverified
        end
      end
    end
  end
end
