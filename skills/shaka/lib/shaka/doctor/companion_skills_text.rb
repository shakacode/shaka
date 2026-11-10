# frozen_string_literal: true

module Shaka
  class Doctor
    # The companion-skills report's wording. The including check supplies `shown` and `@unread`.
    module CompanionSkillsText
      private

      def duplicate_text(duplicates)
        return if duplicates.empty?

        items = duplicates.sort.map { |name, where| "#{name} (#{where.join(', ')})" }
        "Claude Code loads #{duplicates.length} skill name(s) twice: #{items.join(', ')}"
      end

      def broken_text(broken)
        return if broken.empty?

        "#{broken.length} skill link(s) point nowhere: #{broken.map { |path| shown(path) }.join(', ')}"
      end

      def guidance(duplicates, broken)
        steps = []
        steps << 'Keep one copy of each duplicated skill, or disable the plugin that repeats it.' if duplicates.any?
        steps << 'Repoint or remove each broken link.' if broken.any?
        steps << 'Fix access to each path reported as not read, and repair any invalid plugin record.' if @unread.any?
        "#{steps.join(' ')} Doctor changes nothing."
      end
    end
  end
end
