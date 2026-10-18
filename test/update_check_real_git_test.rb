# frozen_string_literal: true

require_relative 'update_check_support'
require 'open3'

# Reads HEAD and ancestry from real repositories, with GitHub's answer stubbed.
class UpdateCheckRealGitTest < Minitest::Test
  include UpdateCheckSupport

  def test_manual_pull_of_a_real_checkout_reads_head_from_disk
    Dir.mktmpdir('shaka-update-pull') do |checkout|
      recorded = commit(checkout, 'first')
      pulled = commit(checkout, 'second')
      git(checkout, 'update-ref', 'refs/remotes/origin/main', pulled)
      result = real_check(checkout, recorded)
      assert_equal 'drift', result.fetch('status')
      assert_includes result.fetch('guidance'), "is at #{pulled[0, 7]}"
    end
  end

  def test_real_unpushed_commit_or_rollback_is_not_a_pull
    Dir.mktmpdir('shaka-update-local') do |checkout|
      first = commit(checkout, 'first')
      second = commit(checkout, 'second')
      git(checkout, 'update-ref', 'refs/remotes/origin/main', second)
      git(checkout, 'checkout', '--quiet', first)
      assert_equal 'not_a_pull', real_check(checkout, second).fetch('reason')
      git(checkout, 'checkout', '--quiet', '-')
      commit(checkout, 'local')
      assert_equal 'not_a_pull', real_check(checkout, second).fetch('reason')
    end
  end

  private

  def real_check(checkout, recorded)
    runner = lambda do |argv, directory|
      argv.first == 'git' ? Shaka::UpdateCheck::Launch.capture(argv, directory) : ['{"status":"identical"}', '', true]
    end
    Shaka::UpdateCheck.new(source: SOURCE.merge('revision' => recorded), branch: 'main', checkout:,
                           helper: '/installed/shaka', runner:).result
  end

  def git(directory, *arguments)
    command = ['git', '-C', directory, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', *arguments]
    output, status = Open3.capture2(*command)
    raise "git #{arguments.first} failed" unless status.success?

    output.strip
  end

  def commit(directory, message)
    git(directory, 'init', '--quiet') unless File.directory?(File.join(directory, '.git'))
    git(directory, 'commit', '--quiet', '--allow-empty', '-m', message)
    git(directory, 'rev-parse', 'HEAD')
  end
end
