# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/seam_upgrade_fixture'

class SeamUpgradeRelativeReferenceTest < Minitest::Test
  include SeamUpgradeFixture

  README = Class.new do
    include Shaka::Seam::InitializerReadme

    public :readme_source
  end.new

  def test_generated_pointer_names_the_new_layout
    with_repository do |root|
      path = write_tracked(root, '.agents/shaka.md', README.readme_source(Shaka::Configuration::Layout::LEGACY))
      preview = report(root)
      assert_includes preview.fetch('references').map { |item| item.fetch('kind') }, 'relative old-layout reference'
      apply_upgrade(root)
      assert_equal README.readme_source(Shaka::Configuration::Layout::NEW), File.read(path)
    end
  end

  def test_command_directory_notes_are_rewritten
    with_repository do |root|
      source = "Policy: ../agent-workflow.yml\nTrust: `trusted-github-actors.yml`\nRun test here.\n"
      path = write_tracked(root, '.agents/bin/README.md', source)
      apply_upgrade(root)
      assert_equal "Policy: ../shaka/config.yml\nTrust: `../shaka/trusted-github-actors.yml`\nRun test here.\n",
                   File.read(path)
    end
  end

  def test_executable_relative_reference_blocks
    with_repository do |root|
      path = write_tracked(root, '.agents/tools/check', "#!/bin/sh\ncat ../agent-workflow.yml\n")
      File.chmod(0o755, path)
      commit_fixture(root, 'executable tool')
      assert_blocked_with(root, 'relative old-layout reference')
    end
  end

  def test_binary_file_in_old_directory_does_not_block
    with_repository do |root|
      write_tracked(root, '.agents/logo.png', "\x89PNG\0bin/test\0".b)
      assert_equal 'ready', report(root).fetch('status')
    end
  end

  def test_names_outside_the_old_directory_are_not_rewritten
    with_repository do |root|
      source = "Each repository keeps agent-workflow.yml and bin/test.\n"
      path = write_tracked(root, 'docs/notes.md', source)
      apply_upgrade(root)
      assert_equal source, File.read(path)
    end
  end
end
