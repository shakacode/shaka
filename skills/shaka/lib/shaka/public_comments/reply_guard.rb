# frozen_string_literal: true

require_relative '../error'
require_relative 'authors'
require_relative 'trust_config'

module Shaka
  module PublicComments
    # Stops an inline reply when a public thread includes an author comments would exclude.
    # The refusal posts nothing, including no note that the author is approved or excluded.
    class ReplyGuard
      VISIBILITIES = %w[public private internal].freeze

      def initialize(github, trust_config:, machine_path:)
        @github = github
        @trust_config = trust_config
        @machine_path = machine_path
      end

      def check(listed, target)
        return unless target

        participants = participants_for(listed, target)
        require_root(participants, target)
        return unless public?

        refuse(excluded(participants, target))
      end

      private

      def participants_for(listed, target)
        listed.select { |item| participant?(item, target) }
      end

      def participant?(item, target)
        item.is_a?(Hash) && (item['id'] == target || item['in_reply_to_id'] == target)
      end

      def require_root(participants, target)
        root = participants.find { |item| item['id'] == target }
        raise Error, 'Inline thread root is not in the comment list. No comment was posted.' unless root
        return if root['in_reply_to_id'].nil?

        raise Error, 'Inline reply target must be the thread root. No comment was posted.'
      end

      def public?
        visibility = @github.api("repos/#{@github.repository}")['visibility']
        raise Error, 'Repository visibility is unavailable.' unless VISIBILITIES.include?(visibility)

        visibility == 'public'
      end

      def excluded(participants, target)
        Authors.new(@github, public_repo: true, trust_config: config).screen(
          { 'inline_comments' => participants }, thread_index: index(participants, target)
        ).fetch('excluded_interactions')
      end

      def config
        return @trust_config if @trust_config

        loader = TrustConfig.new(@github, machine_path: @machine_path)
        loader.load(base_oid: loader.default_base_oid)
      end

      def index(participants, target)
        meta = { 'thread_id' => "thread-#{target}", 'is_resolved' => false }
        participants.to_h { |item| [item['id'], meta] }
      end

      def refuse(rows)
        return if rows.empty?

        names = rows.filter_map { |row| row['author'] }.uniq
        detail = names.empty? ? 'an excluded author' : names.join(', ')
        raise Error, "Refusing to reply in a public thread that includes an excluded author (#{detail}). " \
                     'No comment was posted.'
      end
    end
  end
end
