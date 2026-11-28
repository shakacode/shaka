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
    # From :// to the last @ on the same line, so a password with spaces, slashes, or @ never prints;
    # it may also drop text after a URL on that line, but never crosses into the next line.
    USERINFO = %r{://[^\n]*@}

    # Drops user:password@ from any URL in text that a command prints.
    def self.redact(text) = text.to_s.gsub(USERINFO, '://')
    SHA = Destination::SHA
    ENVIRONMENT = Destination::ENVIRONMENT

    GUIDANCE = {
      'unchanged' => 'The remote branch is where this task left it. Continue.',
      'not_pushed' => 'The branch is not on the remote and this task never pushed it. Continue.',
      'moved' => 'Someone else changed the remote branch. Pause, preserve local work, fetch and inspect the ' \
                 'new commits, and report them. Accept the head once reconciled.',
      'unrecorded' => 'The branch is on the remote but this checkout never accepted a head. Pause, inspect ' \
                      'the remote commits, and accept the head once reconciled.',
      'disappeared' => 'The pushed branch is gone. Pause, keep local work, and report it. To push it again ' \
                       'once the user agrees, run `branch accept --absent`, then `branch push`.',
      'unconfirmed' => 'The push landed but its head could not be recorded. Pause, run `branch check`, and ' \
                       'accept pushed_head only if the remote still holds it.',
      'unreadable' => 'The remote branch could not be read, so a teammate push cannot be ruled out. Pause, ' \
                      'preserve local work, and report the error.'
    }.freeze

    attr_reader :branch

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
      local = git('rev-parse', '--verify', "refs/heads/#{@branch}").strip # the task branch, even if HEAD moves
      { 'state' => state, 'branch' => @branch, 'remote' => @remote, 'accepted' => accepted,
        'live' => live.is_a?(String) ? live : nil, 'local' => local,
        'rewrites' => rewrites?(accepted, local), 'guidance' => GUIDANCE.fetch(state),
        'error' => (BranchHead.redact(live[:error]) if state == 'unreadable') }.compact
    end

    # Accepting records only what the remote holds now, so a stale or mistyped SHA cannot be accepted.
    def accept(head, absent: false)
      raise Error, 'Pass --head SHA or --absent.' unless absent ^ !head.nil?

      live = @destination.head
      raise Error, "Cannot read #{@remote}/#{@branch}: #{live[:error]}" if live.is_a?(Hash)

      absent ? accept_absent(live) : accept_head(head, live)
      check
    end

    # Pushes the task branch tip read at the check, only from a safe state and leased on the accepted head, then
    # accepts it. Dropping the accepted head from history needs rewrite: true, as an intended rebase does.
    # A push that lands but cannot be accepted reports the pushed commit and keeps the pausing state.
    def push(rewrite: false)
      before = check
      return before.merge('pushed' => false) unless SAFE.include?(before['state'])
      raise Error, "Missing #{before['accepted']}; use --rewrite for a rebase." if before['rewrites'] && !rewrite

      # Git leaves an up-to-date branch alone, so the commit got there by someone else's push.
      return check.merge('pushed' => false) unless @destination.push(before['accepted'], before['local'])

      record_push(before['local'])
    end

    private

    # A failed acceptance after a landed push pauses as unconfirmed, without another read that could fail too.
    def record_push(sha)
      pushed = { 'pushed' => true, 'pushed_head' => sha }
      accept(sha).merge(pushed)
    rescue Error => e
      { 'state' => 'unconfirmed', 'branch' => @branch, 'remote' => @remote, 'guidance' => GUIDANCE['unconfirmed'],
        'error' => BranchHead.redact(e.message) }.merge(pushed)
    end

    def accept_head(head, live)
      raise Error, "--head must be a full 40-character SHA, not #{head.inspect}." unless head.match?(SHA)
      raise Error, "#{@remote}/#{@branch} is not on the remote; nothing to accept." unless live
      raise Error, "#{@remote}/#{@branch} is at #{live}, not #{head}; check it again." unless live == head
      raise Error, "#{@branch} lacks #{head}; combine it first." unless ancestor?(head, "refs/heads/#{@branch}")

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

    # A leased push from a tip that lacks the accepted head drops pushed commits, which only a rebase intends.
    # An accepted commit missing from this clone counts as a rewrite, since its ancestry cannot be shown.
    def rewrites?(accepted, local) = accepted ? !ancestor?(accepted, local) : false

    # Accepting a head the local branch lacks would let work continue on a stale tip.
    def ancestor?(commit, descendant)
      _output, _error, status = Open3.capture3(ENVIRONMENT, 'git', '-C', @root, 'merge-base', '--is-ancestor', commit,
                                               descendant)
      status.success?
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
      # The full ref, since --short spells a branch shadowed by a same-named tag as heads/NAME.
      git('symbolic-ref', '--quiet', 'HEAD').strip.delete_prefix('refs/heads/')
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
