# frozen_string_literal: true

require_relative 'merge_request'
require_relative 'trust_config'

module Shaka
  class GitLab
    # Exposes discussion prose only after native actor and repository-source checks.
    class Comments
      def initialize(merge_request:)
        @mr = merge_request
        @client = merge_request.client
      end

      def call(head:, target:)
        project = @client.project
        raise Error, 'GitLab internal-project comment reads are not supported.' if project['visibility'] == 'internal'

        packet = @mr.stable_read(head:, target:) { read_packet(project, head, target) }
        verify_project(project)
        verify_sources(packet)
        packet
      end

      private

      def read_packet(project, head, target)
        discussions = @mr.discussions
        screened = project['visibility'] == 'public' ? public_notes(project, discussions) : private_notes(discussions)
        attach_positions(screened, discussions)
        { 'provider' => 'gitlab', 'host' => @client.host, 'head' => head, 'target' => target,
          'visibility' => project.fetch('visibility') }.merge(screened)
      end

      def attach_positions(screened, discussions)
        native = discussions.flat_map { |discussion| discussion.fetch('notes') }
        positions = native.to_h { |note| [note.fetch('id'), note['position']] }
        raise Error, 'GitLab discussions returned duplicate note IDs.' unless positions.length == native.length

        screened.fetch('notes').each do |note|
          position = positions.fetch(note.fetch('id'))
          note['position'] = position if position
        end
      end

      def verify_project(project)
        fields = %w[id visibility path_with_namespace web_url]
        return if project.slice(*fields) == @client.project.slice(*fields)

        raise Error, 'GitLab project identity or visibility changed during comment read.'
      end

      def public_notes(project, discussions)
        config = TrustConfig.new(client: @client).load
        screened = ActorTrust.new(client: @client, project_id: project.fetch('id'),
                                  trusted_users: config.fetch(:users), trusted_bots: config.fetch(:bots),
                                  metadata_bots: config.fetch(:metadata_bots)).screen(discussions)
        screened.merge('trust_sources' => config.fetch(:sources))
      end

      def verify_sources(packet)
        return unless packet['visibility'] == 'public'
        return if packet.fetch('trust_sources') == TrustConfig.new(client: @client).load.fetch(:sources)

        raise Error, 'GitLab trusted actor source changed during comment read.'
      end

      def private_notes(discussions)
        notes = ActorTrust::Input.notes(discussions).map do |discussion, note|
          note.merge('discussion_id' => discussion, 'trust' => 'private')
        end
        { 'notes' => notes, 'metadata_only' => [], 'withheld' => [], 'trust_sources' => [] }
      end
    end
  end
end
