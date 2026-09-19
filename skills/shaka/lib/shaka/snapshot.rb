# frozen_string_literal: true

require 'json'
require 'open3'
require 'optparse'
require_relative 'error'
require_relative 'snapshot/bytes'
require_relative 'snapshot/options'
require_relative 'snapshot/plan'
require_relative 'snapshot/policy'
require_relative 'snapshot/tree'

module Shaka
  # Publishes unfinished work to a branch that carries no pull request.
  #
  # The published commit has no parent and holds only the files the plan listed, so what
  # leaves the machine is exactly what was read. Local commits do not travel; the plan names
  # them so the recovery note can say they exist only in that checkout.
  class Snapshot
    PREFIX = 'wip/'

    # Status paths are literal paths, not pathspecs: a file named `:(glob)**` would
    # otherwise match far more than itself, and the plan would stop describing what gets
    # published.
    LITERAL = { 'GIT_LITERAL_PATHSPECS' => '1' }.freeze

    def self.run(arguments)
      new(arguments).run
    rescue OptionParser::ParseError, SystemCallError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def initialize(arguments)
      @arguments = arguments
      @options = {}
    end

    def run
      parse
      @root = Bytes.trimmed(capture('rev-parse', '--show-toplevel'))
      @branch = named_branch

      @options[:delete] ? delete : publish
      0
    end

    private

    # `symbolic-ref` answers before the first commit exists, where `rev-parse HEAD` cannot,
    # and still refuses a detached head. A repository with drafts and no commits is exactly
    # the case a snapshot is for.
    def named_branch
      Bytes.trimmed(git('symbolic-ref', '--quiet', '--short', 'HEAD'))
    rescue Error
      raise Error, 'Snapshot needs a named branch, not a detached head.'
    end

    def parse
      @options = Options.parse(@arguments)
    end

    def snapshot_branch = "#{PREFIX}#{@branch}"

    # A ref name keeps its bytes for git and is rendered for anything a person reads.
    def readable_branch = Bytes.readable(snapshot_branch)

    def reference = "refs/heads/#{snapshot_branch}"

    def delete
      remove unless remote_commit.empty?
      report('deleted' => readable_branch, 'existed' => !remote_commit.empty?)
    end

    # An exact lease needs no remote-tracking ref, which a fresh checkout does not have.
    def remote_commit
      @remote_commit ||= Bytes.first_field(git('ls-remote', @options[:remote], reference))
    end

    # Planning never asks the remote anything, not even a question it could recover from:
    # an unreachable or slow remote must not delay a plan. Only a push compares against the
    # remote's own answer, and an unreachable one there means no known head.
    def remote_head
      return '' unless @options[:push]

      @remote_head ||= Bytes.first_field(git('ls-remote', @options[:remote], "refs/heads/#{@branch}"))
    rescue Error
      @remote_head = ''
    end

    # Planning reads nothing the remote must answer, so it works while the remote is down.
    def publish
      plan = current_plan
      return settle(plan) if nothing_to_publish?(plan)
      return report(plan) unless @options[:push]

      raise Error, 'This repository sets recovery.snapshot to false.' unless allowed?

      confirm(plan)
      push(plan)
    end

    def allowed?
      Policy.new(root: @root, remote: @options[:remote], git: method(:git)).allows_snapshot?
    end

    def current_plan
      Plan.new(root: @root, branch: readable_branch, remote_head:, git: method(:git)).to_h
    end

    def nothing_to_publish?(plan) = plan['adds'].empty?

    # An earlier stop may have left a snapshot on the remote. With nothing to publish now,
    # leaving it there would keep obsolete work fetchable while the refreshed note says
    # there is none, so publishing nothing removes what publishing left.
    #
    # Removal does not ask the policy. `recovery.snapshot` governs what may be published,
    # and a deletion publishes nothing; a repository that turns the setting off must still
    # be able to clear what earlier runs left, or the setting would strand exactly the work
    # it was set to keep off the remote.
    def settle(plan)
      empty = plan.merge('branch' => nil)
      return report(empty) unless @options[:push]

      refuse_stale(plan)
      return report(empty) if remote_commit.empty?

      remove
      report(empty.merge('deleted' => readable_branch))
    end

    # Deleting takes the same lease as replacing: between reading the remote's value and
    # this push, another publisher may have left the only copy of its own unfinished work.
    def remove
      git('push', "--force-with-lease=#{reference}:#{remote_commit}", @options[:remote], ":#{reference}")
    end

    # The push must publish the plan that was read, not whatever the checkout holds now.
    def confirm(plan)
      raise Error, 'Publishing needs --expect with the digest the plan printed.' if @options[:expect].nil?

      refuse_stale(plan)
    end

    # A command carrying an expectation that no longer matches is stale, and that is true
    # even where the work it would do now is a deletion: the plan it was given named files
    # this checkout no longer has, and the snapshot may be their only remaining copy.
    def refuse_stale(plan)
      return if @options[:expect].nil? || @options[:expect] == plan['digest']

      raise Error, "The checkout changed since that plan; its digest is now #{plan['digest']}."
    end

    def push(plan)
      commit = write_commit(plan)
      git('push', "--force-with-lease=#{reference}:#{remote_commit}", @options[:remote], "#{commit}:#{reference}")
      report(plan.merge('published' => true, 'commit' => commit))
    end

    def write_commit(plan)
      Tree.new(git: method(:git)).commit(tree: plan.fetch('tree'), branch: Bytes.readable(@branch))
    end

    def report(payload)
      puts JSON.pretty_generate(payload)
    end

    def git(*argv, index: nil, environment: {})
      capture(*argv, index:, environment:)
    end

    # Status paths are relative to the repository root, so every command runs there.
    def capture(*argv, index: nil, environment: {})
      environment = LITERAL.merge(environment, index ? { 'GIT_INDEX_FILE' => index } : {})
      location = @root ? ['-C', @root] : []
      output, error, status = Open3.capture3(environment, 'git', *location, *argv)
      raise Error, "git #{argv.first} failed: #{error.lines.first&.strip}" unless status.success?

      output
    end
  end
end
