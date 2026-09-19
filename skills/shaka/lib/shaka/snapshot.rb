# frozen_string_literal: true

require 'json'
require 'open3'
require 'optparse'
require_relative 'error'
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

    def self.run(arguments)
      new(arguments).run
    rescue OptionParser::ParseError, SystemCallError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def initialize(arguments)
      @arguments = arguments.dup
      @options = { remote: 'origin' }
    end

    def run
      parse
      @root = capture('rev-parse', '--show-toplevel').strip
      @branch = git('rev-parse', '--abbrev-ref', 'HEAD').strip
      raise Error, 'Snapshot needs a named branch, not a detached head.' if @branch == 'HEAD'

      @options[:delete] ? delete : publish
      0
    end

    private

    def parse
      parser = option_parser
      parser.parse!(@arguments)
      raise OptionParser::InvalidArgument, parser.to_s unless @arguments.empty?
    end

    def option_parser
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka snapshot [--push] [--remote NAME] [--delete]'
        flags.on('--push', 'Publish the snapshot; without it the plan is printed only') { @options[:push] = true }
        flags.on('--expect DIGEST', 'The digest the plan printed; required with --push') { |v| @options[:expect] = v }
        flags.on('--remote NAME', 'Remote to publish to; default origin') { |name| @options[:remote] = name }
        flags.on('--delete', 'Delete this branch snapshot instead of publishing one') { @options[:delete] = true }
      end
    end

    def snapshot_branch = "#{PREFIX}#{@branch}"

    def reference = "refs/heads/#{snapshot_branch}"

    def delete
      git('push', @options[:remote], '--delete', snapshot_branch) unless remote_commit.empty?
      report('deleted' => snapshot_branch, 'existed' => !remote_commit.empty?)
    end

    # An exact lease needs no remote-tracking ref, which a fresh checkout does not have.
    def remote_commit
      @remote_commit ||= git('ls-remote', @options[:remote], reference).split(/\s/).first.to_s
    end

    # Planning must work offline, so an unreachable remote means no known remote head.
    def remote_head
      @remote_head ||= git('ls-remote', @options[:remote], "refs/heads/#{@branch}").split(/\s/).first.to_s
    rescue Error
      @remote_head = ''
    end

    # Planning reads nothing the remote must answer, so it works while the remote is down.
    def publish
      plan = current_plan
      return report(plan.merge('branch' => nil)) if nothing_to_publish?(plan)
      return report(plan) unless @options[:push]

      raise Error, 'This repository sets recovery.snapshot to false.' unless allowed?

      confirm(plan)
      push(plan)
    end

    def allowed?
      Policy.new(root: @root, remote: @options[:remote], git: method(:git)).allows_snapshot?
    end

    def current_plan
      Plan.new(root: @root, branch: snapshot_branch, remote_head:, git: method(:git)).to_h
    end

    def nothing_to_publish?(plan) = plan['adds'].empty?

    # The push must publish the plan that was read, not whatever the checkout holds now.
    def confirm(plan)
      expected = @options[:expect]
      raise Error, 'Publishing needs --expect with the digest the plan printed.' if expected.nil?
      raise Error, "The checkout changed since that plan; its digest is now #{plan['digest']}." if
        expected != plan['digest']
    end

    def push(plan)
      commit = write_commit(plan)
      git('push', "--force-with-lease=#{reference}:#{remote_commit}", @options[:remote], "#{commit}:#{reference}")
      report(plan.merge('published' => true, 'commit' => commit))
    end

    def write_commit(plan)
      Tree.new(git: method(:git)).commit(tree: plan.fetch('tree'), message:)
    end

    def message
      "Snapshot unfinished work on #{@branch}\n\n" \
        'Published by shaka snapshot. Not for review or merge. This commit has no parent and ' \
        "holds only the files the snapshot listed; the branch it came from is elsewhere.\n"
    end

    def report(payload)
      puts JSON.pretty_generate(payload)
    end

    def git(*argv, index: nil, environment: {})
      capture(*argv, index:, environment:)
    end

    # Status paths are relative to the repository root, so every command runs there.
    def capture(*argv, index: nil, environment: {})
      environment = environment.merge(index ? { 'GIT_INDEX_FILE' => index } : {})
      location = @root ? ['-C', @root] : []
      output, error, status = Open3.capture3(environment, 'git', *location, *argv)
      raise Error, "git #{argv.first} failed: #{error.lines.first&.strip}" unless status.success?

      output
    end
  end
end
