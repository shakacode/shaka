# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'release_preflight_helpers'

class ReleasePreflightNativeTest < Minitest::Test
  include ReleasePreflightHelpers

  def test_accepts_real_evidence_from_a_distinct_trusted_installation
    prepare_native_validation
    @shaka = @producer
    assert_equal 'ready_for_approval', preflight.fetch('status')
  end

  def test_refuses_evidence_from_a_different_installation
    prepare_native_validation
    assert_refused 'validation'
  end

  def test_refuses_a_helper_inside_the_release_checkout
    @shaka = File.join(@root, 'skills/shaka/scripts/shaka')
    assert_refused 'outside the release checkout'
  end

  private

  def prepare_native_validation
    prepare_producer
    path = File.join(@root, '.agents/shaka/bin/validate')
    File.write(path, "#!/bin/sh\nexit 0\n")
    execute('git', 'add', path)
    execute('git', '-c', 'user.name=Release Test', '-c', 'user.email=test@example.com', 'commit', '-qm',
            'Native fixture')
    @head = execute('git', 'rev-parse', 'HEAD').strip
    execute('git', 'push', '--quiet', 'origin', 'main')
    File.write(@validation, execute(@producer, 'evidence', 'run', '--root', @root, '--ref', @head,
                                    '--repository', 'shakacode/shaka', '--command', 'validate'))
  end

  def prepare_producer
    trusted = File.join(@directory, 'trusted')
    environment = { 'HOME' => File.join(@directory, 'installer-home') }
    execute(environment, File.join(ROOT, 'bin/install'), '--repository', @root, '--directory', trusted,
            '--skills-dir', File.join(@directory, 'skills'))
    @producer = File.join(trusted, 'skills/shaka/scripts/shaka')
  end
end
