# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'release_preflight_helpers'

class ReleasePreflightIntegrityTest < Minitest::Test
  include ReleasePreflightHelpers

  def test_rejects_an_altered_install_message
    script = "s = Gem::Specification.load('shaka.gemspec'); s.post_install_message = 'Changed'; " \
             'Gem::Package.build(s, false, false, ARGV.fetch(0))'
    execute(RbConfig.ruby, '-rrubygems/package', '-e', script, @gem)
    assert_refused 'metadata'
  end

  def test_rejects_hidden_gemspec_changes
    execute('git', 'update-index', '--assume-unchanged', 'shaka.gemspec')
    path = File.join(@root, 'shaka.gemspec')
    text = File.read(path).sub('spec.bindir =', "spec.files -= ['skills/shaka/lib/shaka/error.rb']\n  spec.bindir =")
    File.write(path, text)
    execute('gem', 'build', 'shaka.gemspec', '--output', @gem)
    assert_refused 'index flags'
  end

  def test_accepts_a_valid_gem_with_restrictive_umask
    output, error, status = capture(umask: 0o077)
    assert_predicate status, :success?, error
    assert_equal 'ready_for_approval', JSON.parse(output).fetch('status')
  end

  def test_a_fork_origin_cannot_hide_canonical_main_changes
    fork = File.join(@directory, 'fork.git')
    execute('git', 'clone', '--bare', '--quiet', @root, fork)
    execute('git', 'remote', 'set-url', 'origin', fork)
    execute('git', 'config', "url.#{@remote}.insteadOf", 'https://github.com/shakacode/shaka.git')
    execute('git', '--git-dir', @remote, 'update-ref', 'refs/heads/main', "#{@head}^")
    assert_refused 'remote main'
  end

  def test_rejects_skip_worktree_flags
    execute('git', 'update-index', '--skip-worktree', 'shaka.gemspec')
    assert_refused 'index flags'
  end
end
