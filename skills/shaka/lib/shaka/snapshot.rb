# frozen_string_literal: true

require 'json'
require 'open3'
require 'optparse'
require 'tmpdir'
require_relative 'error'
require_relative 'snapshot/changes'
require_relative 'snapshot/screen'

module Shaka
  # Publishes unfinished work to a branch that carries no pull request.
  class Snapshot
    PREFIX = 'wip/'
    SEPARATOR = "\0"

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
        flags.on('--remote NAME', 'Remote to publish to; default origin') { |name| @options[:remote] = name }
        flags.on('--delete', 'Delete this branch snapshot instead of publishing one') { @options[:delete] = true }
      end
    end

    def snapshot_branch = "#{PREFIX}#{@branch}"

    def delete
      git('push', @options[:remote], '--delete', snapshot_branch)
      report('deleted' => snapshot_branch)
    end

    def publish
      plan = plan_for(Changes.new(git('status', '--porcelain', '-uall', '-z').split(SEPARATOR)))
      return report(plan.merge('branch' => nil)) if plan['adds'].empty? && plan['removes'].empty?
      return report(plan) unless @options[:push]

      push(plan)
    end

    def plan_for(changes)
      screen = Screen.new(changes.added)
      { 'branch' => snapshot_branch, 'published' => false, 'adds' => screen.included,
        'removes' => changes.removed, 'held_back' => screen.excluded }
    end

    def push(plan)
      commit = write_commit(plan['adds'], plan['removes'])
      git('push', '--force-with-lease', @options[:remote], "#{commit}:refs/heads/#{snapshot_branch}")
      report(plan.merge('published' => true, 'commit' => commit))
    end

    # A temporary index keeps the working tree and the real index untouched.
    def write_commit(adds, removes)
      Dir.mktmpdir('shaka-snapshot') do |dir|
        index = File.join(dir, 'index')
        parent = git('rev-parse', 'HEAD').strip
        git('read-tree', 'HEAD', index: index)
        git('add', '--force', '--', *adds, index: index) unless adds.empty?
        git('update-index', '--force-remove', '--', *removes, index: index) unless removes.empty?
        tree = git('write-tree', index: index).strip
        git('commit-tree', tree, '-p', parent, '-m', message, index: index).strip
      end
    end

    def message
      "Snapshot unfinished work on #{@branch}\n\nPublished by shaka snapshot. Not for review or merge.\n"
    end

    def report(payload)
      puts JSON.pretty_generate(payload)
    end

    def git(*argv, index: nil)
      environment = index ? { 'GIT_INDEX_FILE' => index } : {}
      output, error, status = Open3.capture3(environment, 'git', *argv)
      raise Error, "git #{argv.first} failed: #{error.lines.first&.strip}" unless status.success?

      output
    end
  end
end
