# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'tmpdir'
require_relative '../skills/shaka/lib/shaka/install/tree'

class InstallJevEntryPointTest < Minitest::Test
  def test_missing_analyze_command_is_rejected
    with_skill do |root, helper|
      File.delete(helper)
      assert_match(/Missing skill entry point/, assert_raises(ArgumentError) { entries(root) }.message)
    end
  end

  def test_nonexecutable_analyze_command_is_rejected
    with_skill do |root, helper|
      File.chmod(0o644, helper)
      assert_match(/not executable/, assert_raises(ArgumentError) { entries(root) }.message)
    end
  end

  def test_missing_ruby_body_is_rejected
    with_skill do |root, helper|
      File.delete("#{helper}.rb")
      assert_match(/Missing skill entry point/, assert_raises(ArgumentError) { entries(root) }.message)
    end
  end

  def test_jev_cannot_be_packaged_without_shaka
    with_skill do |root, _helper|
      error = assert_raises(ArgumentError) { Shaka::Install::Tree.new(['shaka-jev']).entries(root, 'shaka-jev') }
      assert_match(/requires shaka/, error.message)
    end
  end

  private

  def entries(root) = Shaka::Install::Tree.new(%w[shaka shaka-jev]).entries(root, 'shaka-jev')

  def with_skill
    Dir.mktmpdir('jev-entry-point') do |root|
      skill = File.join(root, 'skills/shaka-jev')
      helper = File.join(skill, 'scripts/analyze')
      FileUtils.mkdir_p(File.dirname(helper))
      File.write(File.join(skill, 'SKILL.md'), '# Jev')
      File.write(helper, "#!/usr/bin/env ruby\n")
      File.chmod(0o755, helper)
      File.write("#{helper}.rb", "# frozen_string_literal: true\n")
      yield root, helper
    end
  end
end
