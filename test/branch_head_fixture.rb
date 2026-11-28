# frozen_string_literal: true

require 'open3'
require 'shaka/branch_head/command'
require 'tmpdir'

# Real Git for branch-head tests: a bare origin, this task's clone, and a teammate's clone of the same branch.
module BranchHeadFixture
  BRANCH = 'task/1287-branch-head'

  def setup
    @dir = Dir.mktmpdir('shaka-branch-head')
    @origin = File.join(@dir, 'origin.git')
    @task = File.join(@dir, 'task')
    @teammate = File.join(@dir, 'teammate')
    git(@dir, 'init', '--quiet', '--bare', '--initial-branch=main', @origin)
    git(@dir, 'clone', '--quiet', @origin, @task)
    commit(@task, 'base')
    git(@task, 'push', '--quiet', 'origin', 'HEAD:main')
    git(@task, 'switch', '--quiet', '-c', BRANCH)
  end

  def teardown = FileUtils.remove_entry(@dir)

  private

  def branch_head = Shaka::BranchHead.new(root: @task)

  def bare_copy(name)
    path = File.join(@dir, name)
    git(@dir, 'clone', '--quiet', '--bare', @origin, path)
    path
  end

  def check = branch_head.check

  def accept(sha) = branch_head.accept(sha)

  def push_task(message)
    commit(@task, message)
    git(@task, 'push', '--quiet', 'origin', "HEAD:refs/heads/#{BRANCH}")
    git(@task, 'rev-parse', 'HEAD').strip
  end

  def teammate_push(message)
    git(@dir, 'clone', '--quiet', '--branch', BRANCH, @origin, @teammate) unless Dir.exist?(@teammate)
    commit(@teammate, message)
    git(@teammate, 'push', '--quiet', 'origin', BRANCH)
    git(@teammate, 'rev-parse', 'HEAD').strip
  end

  def commit(root, message)
    git(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
        'commit', '--quiet', '--allow-empty', '-m', message)
  end

  # An explicit identity, since CI runners have none and commits, amends, and annotated tags need one.
  def git(root, *arguments)
    output, status = Open3.capture2e('git', '-c', 'user.name=Test', '-c', 'user.email=test@example.com', '-C', root,
                                     *arguments)
    raise "git #{arguments.join(' ')} failed: #{output}" unless status.success?

    output
  end
end
