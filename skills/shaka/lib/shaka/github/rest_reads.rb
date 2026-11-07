# frozen_string_literal: true

require 'uri'

module Shaka
  class GitHub
    # Reads what `shaka pr` reports over REST, for sessions where GitHub refuses GraphQL.
    module RestReads
      # Snapshot fields REST does not expose. They are left out and named, never reported as
      # false or empty, so a reader cannot mistake "not read" for "no".
      UNREADABLE = %w[reviewDecision viewerCanMergeAsAdmin isInMergeQueue isMergeQueueEnabled mergeQueueEntry].freeze
      PAGE = 100
      MAX_PAGES = 10
      # `gh pr checks` buckets, except that STARTUP_FAILURE fails where gh would leave it pending.
      # Any other state, such as QUEUED, IN_PROGRESS, or STALE, is pending.
      BUCKETS = { 'SUCCESS' => 'pass', 'SKIPPED' => 'skipping', 'NEUTRAL' => 'skipping', 'CANCELLED' => 'cancel',
                  'FAILURE' => 'fail', 'ERROR' => 'fail', 'TIMED_OUT' => 'fail', 'ACTION_REQUIRED' => 'fail',
                  'STARTUP_FAILURE' => 'fail' }.freeze

      # The reader Status and RequiredChecks expect, answered over REST.
      def over_rest = RestView.new(self)

      def rest_snapshot
        pull = api("repos/#{@repository}/pulls/#{@number}")
        head = pull.dig('head', 'sha')
        unless pull['number'] == @number && head.is_a?(String) && pull.dig('base', 'ref').is_a?(String)
          raise Error, 'GitHub did not return the requested pull request.'
        end

        read_over = { 'readOver' => 'rest', 'unknownFields' => unknown_fields(pull) }
        state_fields(pull).merge(ref_fields(pull), size_fields(pull), read_over)
      end

      # Checks and commit statuses on head, shaped as `gh pr checks --json name,state,bucket,link` rows.
      def rest_checks(head)
        runs = every_page("repos/#{@repository}/commits/#{head}/check-runs", 'check_runs')
               .map { |run| check_run_row(run, head) }
        statuses = every_page("repos/#{@repository}/commits/#{head}/status", 'statuses') do |page|
          raise Error, 'GitHub returned commit statuses for another commit.' unless page['sha'] == head
        end
        runs + statuses.map { |status| status_row(status) }
      end

      # Classic protection contexts plus ruleset contexts: what `refUpdateRule` and rulesets give over GraphQL.
      def rest_configured_required_checks(branch) = (classic_contexts(branch) + ruleset_contexts(branch)).uniq

      private

      def state_fields(pull)
        merged = pull['merged'] == true
        { 'id' => pull['node_id'], 'number' => pull['number'], 'url' => pull['html_url'],
          'state' => merged ? 'MERGED' : pull['state'].to_s.upcase, 'isDraft' => pull['draft'], 'merged' => merged,
          # Before merge, REST's merge_commit_sha names a test merge, not a merge commit.
          'mergeCommit' => merged ? { 'oid' => pull['merge_commit_sha'] } : nil,
          'mergeStateStatus' => pull['mergeable_state']&.upcase, 'autoMergeRequest' => pull['auto_merge'] ? {} : nil }
      end

      def ref_fields(pull)
        { 'author' => pull['user'] && { 'login' => pull.dig('user', 'login') },
          'headRefOid' => pull.dig('head', 'sha'), 'baseRefName' => pull.dig('base', 'ref'),
          'headRepository' => repository_name(pull['head']), 'baseRepository' => repository_name(pull['base']) }
      end

      def size_fields(pull)
        labels = Array(pull['labels']).map { |label| { 'name' => label['name'] } }
        { 'changedFiles' => pull['changed_files'], 'additions' => pull['additions'], 'deletions' => pull['deletions'],
          'commits' => { 'totalCount' => pull['commits'] },
          'labels' => { 'totalCount' => labels.size, 'nodes' => labels } }
      end

      def unknown_fields(pull) = UNREADABLE + (pull['auto_merge'] ? ['autoMergeRequest.enabledAt'] : [])

      def repository_name(side)
        name = side.dig('repo', 'full_name') if side.is_a?(Hash)
        name && { 'nameWithOwner' => name }
      end

      # A head check run that names another commit is refused rather than counted for this head.
      def check_run_row(run, head)
        raise Error, 'GitHub returned a check run for another commit.' unless run['head_sha'] == head

        state = (run['status'] == 'completed' ? run['conclusion'] : run['status']).to_s.upcase
        row(run['name'], state, run['details_url'] || run['html_url'])
      end

      def status_row(status) = row(status['context'], status['state'].to_s.upcase, status['target_url'])

      def row(name, state, link)
        raise Error, 'GitHub returned a check without a readable name.' unless name.is_a?(String) && !name.empty?

        { 'name' => name, 'state' => state, 'bucket' => BUCKETS.fetch(state, 'pending'), 'link' => link.to_s }
      end

      # Every row of a paged list, refusing a set too large to read whole.
      def every_page(path, key, &)
        rows = []
        1.upto(MAX_PAGES) do |page|
          batch, total = list_page("#{path}?per_page=#{PAGE}&page=#{page}", key, &)
          rows.concat(batch)
          return rows if batch.size < PAGE || rows.size >= total
        end
        raise Error, "GitHub reported more than #{PAGE * MAX_PAGES} #{key}; refusing to read a truncated set."
      end

      # A page without its rows or total cannot say whether more pages follow.
      def list_page(path, key)
        body = api(path)
        batch, total = body.values_at(key, 'total_count')
        raise Error, "GitHub returned an unreadable #{key} page." unless batch.is_a?(Array) && total.is_a?(Integer)

        yield body if block_given?
        [batch, total]
      end

      # Branch protection whose contexts cannot be read must not count as requiring nothing.
      def classic_contexts(branch)
        data = api("repos/#{@repository}/branches/#{URI.encode_uri_component(branch)}")
        return [] unless data['protected']

        checks = data['protection']['required_status_checks'] if data['protection'].is_a?(Hash)
        contexts = checks['contexts'] if checks.is_a?(Hash)
        return contexts if contexts.is_a?(Array) && contexts.all? { |context| readable_context?(context) }

        raise Error, 'GitHub did not report readable branch protection for the base branch.'
      end

      # Status reads the snapshot first; checks and rules then use that head and base, so one call
      # reads each list once and a head that moves meanwhile still fails Status's comparison.
      class RestView
        def initialize(github)
          @github = github
        end

        def snapshot
          pull = @github.rest_snapshot
          @first ||= pull
          pull
        end

        def checks = @checks ||= @github.rest_checks(first.fetch('headRefOid'))

        def configured_required_checks
          @configured_required_checks ||= @github.rest_configured_required_checks(first.fetch('baseRefName'))
        end

        # REST cannot mark a check required, so the configured rules choose among the head's checks.
        def required_checks = checks.select { |row| configured_required_checks.include?(row['name']) }

        private

        def first = @first || snapshot
      end
    end
  end
end
