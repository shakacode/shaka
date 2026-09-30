# frozen_string_literal: true

require_relative 'evidence_fixture'

class EvidenceGuardCommandTest < Minitest::Test
  include EvidenceFixture

  def test_guard_clear_and_missing_base
    with_checkout do |root, ref|
      args = arguments(root, ref)
      output, = capture_io { assert_equal 0, Shaka::Evidence::Command.run(args + ['--base', ref]) }
      assert_equal 'clear', JSON.parse(output)['status']
      capture_io { assert_equal 1, Shaka::Evidence::Command.run(args) }
    end
  end

  def test_untracked_configuration_is_blocked_with_explicit_setup_flow_supported
    with_checkout do |root, ref|
      args = arguments(root, ref) + ['--base', ref]
      File.write(File.join(root, '.agents/shaka.md'), 'legacy')
      capture_io { assert_equal 1, Shaka::Evidence::Command.run(args) }
      capture_io { assert_equal 0, Shaka::Evidence::Command.run(args + ['--flow', 'setup']) }
    end
  end

  private

  def arguments(root, ref)
    ['guard', '--root', root, '--ref', ref, '--repository', 'shakacode/shaka', '--head', ref]
  end
end
