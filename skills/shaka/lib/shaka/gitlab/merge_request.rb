# frozen_string_literal: true

require_relative '../gitlab'

module Shaka
  class GitLab
    # Raw native discussions still need author screening before exposing their prose.
    module MergeRequestDiscussions
      def discussions
        current = snapshot
        result = @client.api_list("#{project_path(current.fetch('project_id'))}/discussions")
        unless result.all? { |item| discussion?(item, current) }
          raise Error, 'GitLab returned malformed discussion evidence.'
        end

        result
      end

      private

      def discussion?(item, current)
        text?(item['id']) && [true, false].include?(item['individual_note']) &&
          item['notes'].is_a?(Array) && !item['notes'].empty? && item['notes'].all? { |note| note?(note, current) }
      end

      def note?(note, current)
        note.is_a?(Hash) && note_identity?(note, current) && note_payload?(note) && position?(note['position'])
      end

      def note_payload?(note)
        note['body'].is_a?(String) && note['body'].valid_encoding? &&
          [true, false].include?(note['system']) && author?(note['author'])
      end

      def note_identity?(note, current)
        positive_id?(note['id']) && note['project_id'] == current['project_id'] &&
          note['noteable_id'] == current['id'] && note['noteable_type'] == 'MergeRequest'
      end

      def author?(author)
        author.is_a?(Hash) && positive_id?(author['id']) && text?(author['username']) &&
          (!author.key?('bot') || [true, false].include?(author['bot']))
      end

      def position?(position)
        position.nil? || (position.is_a?(Hash) && text?(position['position_type']) &&
          position.values_at('base_sha', 'start_sha', 'head_sha').all? { |sha| commit?(sha) })
      end
    end

    # Reads native MR evidence without assigning GitHub review or merge meanings.
    class MergeRequest
      include MergeRequestDiscussions

      IDENTITY = %w[id iid project_id source_project_id target_project_id source_branch target_branch sha draft
                    diff_refs].freeze

      attr_reader :client, :number

      def initialize(client:, number:)
        unless number.to_s.ascii_only? && number.to_s.match?(/\A[1-9]\d*\z/)
          raise Error, 'Expected a positive merge request IID.'
        end

        @client = client
        @number = number.to_i
      end

      def snapshot
        project_id = @client.project.fetch('id')
        result = @client.api(project_path(project_id))
        unless matching_identity?(result, project_id) && revision_fields?(result) && diff_refs?(result['diff_refs'])
          raise Error, 'GitLab did not return the requested merge request identity.'
        end

        result
      end

      def path = project_path(@client.project.fetch('id'))

      def stable_read(head:, target:)
        raise Error, 'Expected a full head SHA and target branch.' unless commit?(head) && text?(target)

        first = snapshot
        verify_expected(first, head, target)
        expected = identity(first)
        result = yield first
        verify_after(expected, head, target)
        result
      end

      private

      def matching_identity?(result, project_id)
        positive_id?(result['id']) && result['iid'] == @number && result['project_id'] == project_id &&
          result['target_project_id'] == project_id && positive_id?(result['source_project_id'])
      end

      def positive_id?(value) = value.is_a?(Integer) && value.positive?

      def project_path(project_id) = "projects/#{project_id}/merge_requests/#{@number}"

      def verify_expected(result, head, target)
        return if result.values_at('state', 'sha', 'target_branch') == ['opened', head, target]

        raise Error, 'GitLab merge request is not open at the expected head and target.'
      end

      def verify_after(expected, head, target)
        last = snapshot
        verify_expected(last, head, target)
        return if expected == identity(last)

        raise Error, 'GitLab merge request identity or diff revision changed during the read.'
      end

      def identity(result)
        fields = result.slice(*IDENTITY)
        fields['diff_refs'] = fields['diff_refs']&.sort&.to_h
        JSON.generate(fields)
      end

      def revision_fields?(result)
        commit?(result['sha']) && text?(result['source_branch']) && text?(result['target_branch']) &&
          %w[opened closed merged locked].include?(result['state']) &&
          [true, false].include?(result['draft']) && text?(result['detailed_merge_status'])
      end

      def commit?(value) = value.is_a?(String) && value.ascii_only? && value.match?(/\A[0-9a-f]{40}\z/)

      def diff_refs?(value)
        value.nil? || (value.is_a?(Hash) && (value.empty? ||
          value.values_at('base_sha', 'start_sha', 'head_sha').all? { |sha| commit?(sha) }))
      end

      def text?(value)
        value.is_a?(String) && value.valid_encoding? && !value.strip.empty? && !value.match?(/[[:cntrl:]]/)
      end
    end
  end
end
