# frozen_string_literal: true

require 'date'
require_relative '../gitlab'

module Shaka
  class GitLab
    # Screens public discussion prose with native project and actor evidence.
    class ActorTrust
      # Drops arbitrary profile text and URLs before constructing an output packet.
      module Input
        module_function

        def identity(value)
          valid = value.is_a?(Hash) && identifier?(value['id']) &&
                  value['username'].is_a?(String) && value['username'].ascii_only? &&
                  value['username'].match?(/\A[A-Za-z0-9_.-]{1,255}\z/)
          raise Error, 'GitLab actor identity is malformed.' unless valid

          { 'id' => value['id'], 'username' => value['username'].downcase }
        end

        def notes(discussions)
          raise Error, 'Expected GitLab discussions.' unless discussions.is_a?(Array)

          discussions.flat_map { |discussion| discussion_notes(discussion) }
        end

        def discussion_notes(discussion)
          unless discussion.is_a?(Hash) && discussion['id'].is_a?(String) &&
                 discussion['id'].match?(/\A[0-9a-f]{40}\z/) && discussion['notes'].is_a?(Array)
            raise Error, 'GitLab discussion metadata is malformed.'
          end

          discussion['notes'].map { |note| [discussion['id'], normalized_note(note)] }
        end

        def normalized_note(note)
          valid = note.is_a?(Hash) && identifier?(note['id']) &&
                  [true, false].include?(note['system']) && note['body'].is_a?(String) && note['body'].valid_encoding?
          raise Error, 'GitLab note metadata is malformed.' unless valid

          note.slice('id', 'body', 'system').merge('author' => identity(note['author']))
        end

        def identifier?(value) = value.is_a?(Integer) && value.positive?
      end

      # Rechecks only native fields that can change the prose decision.
      class Evidence
        attr_reader :members, :users

        def initialize(client, project_id, ids)
          @client = client
          @project_id = project_id
          @project = project_metadata
          @members = read_members
          @users = ids.uniq.to_h { |id| [id, read_user(id)] }
        end

        def verify!
          current = self.class.new(@client, @project_id, @users.keys)
          raise Error, 'GitLab actor evidence changed during screening.' unless snapshot == current.snapshot
        end

        def snapshot
          { project: @project, members: member_evidence,
            users: @users.transform_values { |user| user.slice('id', 'username', 'state', 'bot') } }
        end

        private

        def read_members
          members = @client.api_list("projects/#{@project_id}/members/all").map do |member|
            member.merge(Input.identity(member))
          end
          ids = members.map { |member| member.fetch('id') }
          raise Error, 'GitLab membership returned duplicate user IDs.' unless ids.uniq.length == ids.length

          members
        end

        def read_user(id)
          user = @client.api("users/#{id}")
          pair = Input.identity(user)
          raise Error, 'GitLab user ID does not match the requested actor.' unless pair['id'] == id

          user.slice('state', 'bot').merge(pair)
        end

        def project_metadata
          project = @client.project
          unless @project_id.is_a?(Integer) && @project_id.positive? &&
                 project['id'] == @project_id && project['visibility'] == 'public'
            raise Error, 'GitLab actor trust requires the expected public project.'
          end

          project.slice('id', 'path_with_namespace', 'web_url', 'visibility')
        end

        def member_evidence
          fields = %w[id username state access_level membership_state expires_at]
          @members.select { |member| @users.key?(member['id']) }
                  .map { |member| member.slice(*fields) }.sort_by { |member| member.fetch('id') }
        end
      end

      def initialize(client:, project_id:, trusted_users: [], trusted_bots: [], metadata_bots: [])
        @client = client
        @project_id = project_id
        @trusted_users = trusted_users
        @trusted_bots = trusted_bots
        @metadata_bots = metadata_bots
      end

      def screen(discussions)
        rows = Input.notes(discussions)
        evidence = Evidence.new(@client, @project_id, rows.map { |_, note| note.fetch('author').fetch('id') })
        result = { 'notes' => [], 'metadata_only' => [], 'withheld' => [] }
        rows.each { |discussion, note| record(result, discussion, note, evidence) }
        evidence.verify!
        result
      end

      private

      def record(result, discussion, note, evidence)
        author = note.fetch('author')
        user = evidence.users.fetch(author.fetch('id'))
        row = { 'discussion_id' => discussion, 'id' => note.fetch('id'), 'author' => author }
        trust = note['system'] == true ? 'system' : actor_trust(user, note, evidence.members)
        row['body'] = note.fetch('body') if bucket(trust) == 'notes'
        result.fetch(bucket(trust)) << row.merge('trust' => trust || 'untrusted')
      end

      def bucket(trust)
        return 'withheld' unless trust

        %w[metadata_only system].include?(trust) ? 'metadata_only' : 'notes'
      end

      def actor_trust(user, note, members)
        pair = user.slice('id', 'username')
        return unless user['state'] == 'active' && pair == note['author'].slice('id', 'username')
        return bot_trust(pair) if user['bot'] == true
        return unless user['bot'] == false

        human_trust(pair, members)
      end

      def human_trust(pair, members)
        return 'configured_user' if @trusted_users.include?(pair)

        'writer' if members.any? { |member| member.slice('id', 'username') == pair && active_member?(member) }
      end

      def bot_trust(pair)
        return 'metadata_only' if @metadata_bots.include?(pair)

        'configured_bot' if @trusted_bots.include?(pair)
      end

      def active_member?(member)
        level = member['access_level']
        member['state'] == 'active' && [nil, 'active'].include?(member['membership_state']) &&
          level.is_a?(Integer) && level >= 30 && current_expiry?(member['expires_at'])
      end

      def current_expiry?(value)
        value.nil? || (value.is_a?(String) && Date.iso8601(value) > Time.now.utc.to_date)
      rescue Date::Error
        false
      end
    end
  end
end
