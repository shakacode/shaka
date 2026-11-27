# frozen_string_literal: true

require 'open3'
require_relative 'error'

module Shaka
  # Compares the live remote head of the task branch with the head this checkout last accepted,
  # so a teammate's push between or during turns pauses work instead of being built on or overwritten.
  # The accepted head lives in the checkout's own branch config; only `accept` changes it.
  class BranchHead
    SAFE = %w[unchanged not_pushed].freeze
    SHA = /\A\h{40}\z/

    GUIDANCE = {
      'unchanged' => 'The remote branch is where this task left it. Continue.',
      'not_pushed' => 'The branch is not on the remote and this task never pushed it. Continue.',
      'moved' => 'Someone else changed the remote branch. Pause edits and publication and preserve local ' \
                 'work. Fetch it, inspect the new commits, and report them. After reconciling, accept the ' \
                 'new head, then rerun validation and review for the head you push.',
      'unrecorded' => 'This checkout has no accepted head for a branch that is already on the remote. Pause ' \
                      'edits and publication, inspect the remote commits, and accept the head once it is ' \
                      'reconciled with local work.',
      'disappeared' => 'The remote branch this task pushed is gone. Pause edits and publication, preserve ' \
                       'local work, and report it. Push again only when the user decides to.',
      'unreadable' => 'The remote branch could not be read, so a teammate push cannot be ruled out. Pause ' \
                      'edits and publication, preserve local work, and report the error.'
    }.freeze

    def initialize(root:, remote: 'origin', branch: nil)
      @root = root
      @remote = remote
      @branch = branch || current_branch
    end

    def check
      live = live_head
      accepted = accepted_head
      state = state_for(live, accepted)
      { 'state' => state, 'branch' => @branch, 'remote' => @remote, 'accepted' => accepted,
        'live' => live.is_a?(String) ? live : nil, 'local' => git('rev-parse', 'HEAD').strip,
        'lease' => lease(accepted), 'rewrites' => rewrites?(accepted), 'guidance' => GUIDANCE.fetch(state),
        'error' => (live[:error] if state == 'unreadable') }.compact
    end

    # Accepting records only what the remote holds now, so a stale or mistyped SHA cannot be accepted.
    def accept(head, absent: false)
      raise Error, 'Pass --head SHA or --absent.' unless absent ^ !head.nil?

      live = live_head
      raise Error, "Cannot read #{@remote}/#{@branch}: #{live[:error]}" if live.is_a?(Hash)

      absent ? accept_absent(live) : accept_head(head, live)
      check
    end

    private

    def accept_head(head, live)
      raise Error, "--head must be a full 40-character SHA, not #{head.inspect}." unless head.match?(SHA)
      raise Error, "#{@remote}/#{@branch} is not on the remote; nothing to accept." unless live
      raise Error, "#{@remote}/#{@branch} is at #{live}, not #{head}; check it again." unless live == head

      git('config', '--local', config_key, head)
    end

    def accept_absent(live)
      raise Error, "#{@remote}/#{@branch} is at #{live}; accept that head instead." if live

      git('config', '--local', '--unset-all', config_key) if accepted_head
    end

    def state_for(live, accepted)
      return 'unreadable' if live.is_a?(Hash)
      return accepted ? 'disappeared' : 'not_pushed' unless live
      return 'unrecorded' unless accepted

      live == accepted ? 'unchanged' : 'moved'
    end

    # A leased push from a HEAD that lacks the accepted head drops pushed commits, which only a rebase intends.
    # An accepted commit missing from this clone counts as a rewrite, since its ancestry cannot be shown.
    def rewrites?(accepted)
      return false unless accepted

      _output, _error, status = Open3.capture3('git', '-C', @root, 'merge-base', '--is-ancestor', accepted, 'HEAD')
      !status.success?
    end

    # The value for `git push --force-with-lease`; an empty expectation means the branch must not exist yet.
    def lease(accepted) = "--force-with-lease=refs/heads/#{@branch}:#{accepted}"

    # ls-remote --exit-code returns 2 when the remote answers without the branch; any other failure is unreadable.
    # Its pattern also matches refs that merely end in the branch's path, so only the exact ref counts.
    def live_head
      output, error, status = Open3.capture3({ 'GIT_TERMINAL_PROMPT' => '0' }, 'git', '-C', @root, 'ls-remote',
                                             '--exit-code', @remote, "refs/heads/#{@branch}")
      return exact_head(output) if status.success?
      return if status.exitstatus == 2

      { error: error.strip.empty? ? "git ls-remote exited #{status.exitstatus}" : error.strip }
    end

    def exact_head(output)
      shas = output.lines.filter_map do |line|
        sha, ref = line.chomp.split("\t", 2)
        sha if ref == "refs/heads/#{@branch}"
      end
      return shas.first if shas.length == 1 && shas.first.match?(SHA)

      shas.empty? ? nil : { error: "Unexpected ls-remote output for refs/heads/#{@branch}." }
    end

    # git config --get exits 1 for a missing key; any other failure must not read as "no record".
    def accepted_head
      output, error, status = Open3.capture3('git', '-C', @root, 'config', '--local', '--get', config_key)
      return output.strip if status.success?
      return if status.exitstatus == 1

      raise Error, "Cannot read #{config_key}: #{error.strip}"
    end

    def config_key = "branch.#{@branch}.shakaAcceptedHead"

    def current_branch
      git('symbolic-ref', '--quiet', '--short', 'HEAD').strip
    rescue Error
      raise Error, 'No branch is checked out; pass --branch NAME.'
    end

    def git(*arguments)
      output, error, status = Open3.capture3('git', '-C', @root, *arguments)
      raise Error, "git #{arguments.first} failed: #{error.strip}" unless status.success?

      output
    end
  end
end
