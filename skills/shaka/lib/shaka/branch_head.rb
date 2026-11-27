# frozen_string_literal: true

require 'open3'
require_relative 'branch_head/destination'
require_relative 'error'

module Shaka
  # Compares the live head of the checked-out branch at its push destination with the head this checkout
  # last accepted, so a teammate's push between or during turns pauses work instead of being built on or
  # overwritten. The accepted head lives in the checkout's own branch config; `accept` and `push` change it.
  class BranchHead
    SAFE = %w[unchanged not_pushed].freeze
    SHA = Destination::SHA
    ENVIRONMENT = Destination::ENVIRONMENT

    GUIDANCE = {
      'unchanged' => 'The remote branch is where this task left it. Continue.',
      'not_pushed' => 'The branch is not on the remote and this task never pushed it. Continue.',
      'moved' => 'Someone else changed the remote branch. Pause, preserve local work, fetch and inspect the ' \
                 'new commits, and report them. Accept the head once reconciled.',
      'unrecorded' => 'The branch is on the remote but this checkout never accepted a head. Pause, inspect ' \
                      'the remote commits, and accept the head once reconciled.',
      'disappeared' => 'The remote branch this task pushed is gone. Pause, preserve local work, and report it.',
      'unreadable' => 'The remote branch could not be read, so a teammate push cannot be ruled out. Pause, ' \
                      'preserve local work, and report the error.'
    }.freeze

    def initialize(root:)
      @root = root
      @branch = current_branch
      @destination = Destination.new(root:, branch: @branch)
      @remote = @destination.remote
    end

    def check
      live = @destination.head
      accepted = accepted_head
      state = state_for(live, accepted)
      { 'state' => state, 'branch' => @branch, 'remote' => @remote, 'accepted' => accepted,
        'live' => live.is_a?(String) ? live : nil, 'local' => git('rev-parse', 'HEAD').strip,
        'rewrites' => rewrites?(accepted), 'guidance' => GUIDANCE.fetch(state),
        'error' => (live[:error] if state == 'unreadable') }.compact
    end

    # Accepting records only what the remote holds now, so a stale or mistyped SHA cannot be accepted.
    def accept(head, absent: false)
      raise Error, 'Pass --head SHA or --absent.' unless absent ^ !head.nil?

      live = @destination.head
      raise Error, "Cannot read #{@remote}/#{@branch}: #{live[:error]}" if live.is_a?(Hash)

      absent ? accept_absent(live) : accept_head(head, live)
      check
    end

    # Pushes HEAD only from a safe state, leased on the accepted head, then accepts what it pushed.
    # A push that would drop the accepted head from history needs rewrite: true, as an intended rebase does.
    def push(rewrite: false)
      before = check
      return before.merge('pushed' => false) unless SAFE.include?(before['state'])
      if before['rewrites'] && !rewrite
        raise Error, "HEAD lacks the accepted head #{before['accepted']}; pass --rewrite only for an intended rebase."
      end

      @destination.push(before['accepted'])
      accept(before['local']).merge('pushed' => true)
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

      _output, _error, status = Open3.capture3(ENVIRONMENT, 'git', '-C', @root, 'merge-base', '--is-ancestor',
                                               accepted, 'HEAD')
      !status.success?
    end

    # git config --get exits 1 for a missing key; any other failure must not read as "no record".
    def accepted_head
      output, error, status = Open3.capture3(ENVIRONMENT, 'git', '-C', @root, 'config', '--local', '--get',
                                             config_key)
      return output.strip if status.success?
      return if status.exitstatus == 1

      raise Error, "Cannot read #{config_key}: #{error.strip}"
    end

    def config_key = "branch.#{@branch}.shakaAcceptedHead"

    def current_branch
      git('symbolic-ref', '--quiet', '--short', 'HEAD').strip
    rescue Error
      raise Error, 'No branch is checked out; check out the task branch first.'
    end

    def git(*arguments)
      output, error, status = Open3.capture3(ENVIRONMENT, 'git', '-C', @root, *arguments)
      raise Error, "git #{arguments.first} failed: #{error.strip}" unless status.success?

      output
    end
  end
end
