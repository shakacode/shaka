# frozen_string_literal: true

require_relative 'trusted_command_fixture'

# Nothing the trusted copy created outlives the run, whatever the run did.
class EvidenceTrustedCommandCleanupTest < Minitest::Test
  include TrustedCommandFixture

  # Stands in for a validator that cleans untracked files, such as `git clean -fdx`.
  SELF_REMOVING = "#!/bin/sh\nrm -- \"$0\"\n"

  def test_run_tolerates_a_command_that_removes_the_copy
    with_older_branch(validate: SELF_REMOVING) do |root, trusted, _head|
      result = run_check(root, trusted, command: 'validate')

      assert_equal 'completed', result.fetch('status')
      refute_path_exists File.join(root, '.agents')
    end
  end

  def test_run_keeps_unrelated_agents_files
    with_older_branch do |root, trusted, _head|
      FileUtils.mkdir_p(File.join(root, '.agents/skills'))
      File.write(File.join(root, '.agents/skills/note.md'), "kept\n")
      run_check(root, trusted, command: 'validate')

      assert_equal %w[skills], Dir.children(File.join(root, '.agents'))
    end
  end

  def test_failed_write_removes_the_partial_copy
    with_older_branch do |root, trusted, _head|
      copy = trusted_copy(root, trusted)
      unwritable = Object.new
      def unwritable.to_s = raise(Errno::ENOSPC)
      copy.instance_variable_set(:@text, unwritable)

      assert_raises(Errno::ENOSPC) { copy.with { flunk 'command ran' } }
      refute_path_exists File.join(root, '.agents')
    end
  end

  def test_trusted_copy_refuses_a_symlinked_parent
    with_older_branch do |root, trusted, _head|
      Dir.mktmpdir do |outside|
        copy = trusted_copy(root, trusted)
        File.symlink(outside, File.join(root, '.agents'))

        assert_raises(Shaka::Error) { copy.with { flunk 'command ran' } }
        assert_empty Dir.children(outside)
      end
    end
  end
end
