# frozen_string_literal: true

require_relative '../public_comments/reader'

module Shaka
  # The agent selects obsolete bot reports; GitHub preserves their content behind its disclosure.
  class BotReviewHistory
    QUERY = <<~GRAPHQL
      query($id: ID!) {
        node(id: $id) { __typename ... on IssueComment {
          id url body isMinimized minimizedReason viewerCanMinimize
          author { __typename login }
        } }
      }
    GRAPHQL
    MUTATION = <<~GRAPHQL
      mutation($id: ID!) {
        minimizeComment(input: {subjectId: $id, classifier: OUTDATED}) {
          minimizedComment { isMinimized minimizedReason }
        }
      }
    GRAPHQL

    def initialize(github, reader: nil)
      @github = github
      @reader = reader || PublicComments::Reader.new(github)
    end

    def collapse(ids, head:)
      report = { 'collapsed' => [], 'already_minimized' => [], 'unavailable' => [] }
      rows = @reader.call(expected_head: head).fetch('issue_comments')
      ids.uniq.each { |id| minimize(id, rows.find { |row| row['id'] == id }, head, report) }
      report
    rescue Error => e
      report['unavailable'] << e.message
      report
    end

    private

    def minimize(id, row, head, report)
      node = selected_node(id, row)
      verify_head(head)
      node = read(node['id'])
      verify_comment(node, row)
      return report['already_minimized'] << id if node['isMinimized']

      minimize_node(node, row)
      report['collapsed'] << id
      verify_head(head)
    rescue Error => e
      report['unavailable'] << "Comment #{id}: #{e.message}"
    end

    def selected_node(id, row)
      raise Error, 'Selected comment was not admitted by the trusted comment reader.' unless row

      rest = @github.api("repos/#{@github.repository}/issues/comments/#{id}")
      read(rest['node_id']).tap { |node| verify_comment(node, row) }
    end

    def minimize_node(node, row)
      unless node['viewerCanMinimize']
        raise Error, 'GitHub does not permit this account to minimize the selected comment.'
      end

      @github.graphql(MUTATION, id: node['id'])
      stored = read(node['id'])
      verify_comment(stored, row)
      raise Error, 'GitHub did not confirm outdated minimization.' unless
        stored['isMinimized'] == true && stored['minimizedReason'] == 'outdated'
    end

    def read(id)
      raise Error, 'Selected issue comment has no node identifier.' unless id.is_a?(String) && !id.empty?

      node = @github.graphql(QUERY, id: id)['node']
      raise Error, 'Selected issue comment is unavailable.' unless node.is_a?(Hash)

      node
    end

    def verify_comment(node, row)
      raise Error, 'Selected comment is not the admitted bot issue comment, or its content changed.' unless
        admitted_bot?(node, row) && node['__typename'] == 'IssueComment' &&
        node['url'] == row['url'] && node['body'] == row['body']
    end

    def admitted_bot?(node, row)
      node.dig('author', '__typename') == 'Bot' &&
        "#{node.dig('author', 'login').to_s.delete_suffix('[bot]')}[bot]" == row['author']
    end

    def verify_head(head)
      pull = @github.snapshot
      raise Error, 'PR closed or head changed during minimization.' unless
        pull['state'] == 'OPEN' && pull['headRefOid'] == head
    end
  end
end
