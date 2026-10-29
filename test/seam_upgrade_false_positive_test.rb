# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/seam_upgrade_fixture'

# Assertions about one file's blockers in a fresh fixture repository.
module SeamUpgradeFileBlockers
  include SeamUpgradeFixture

  private

  def assert_unblocked(name, source)
    with_repository do |root|
      write_tracked(root, name, source)
      blockers = plan_for(root).blockers
      assert_empty(blockers.grep(/\A#{Regexp.escape(name)}:/), blockers.join("\n"))
    end
  end

  def assert_file_blocked(name, source)
    with_repository do |root|
      write_tracked(root, name, source)
      assert_includes(plan_for(root).blockers.join("\n"), "#{name}:")
    end
  end
end

# Shapes from the react_on_rails conversion (#924) that keep their meaning after the upgrade,
# each beside the nearby shape that still needs a hand repair.
class SeamUpgradeFalsePositiveTest < Minitest::Test
  include SeamUpgradeFileBlockers

  STILL_BLOCKED = {
    'ci/notes.txt' => %(sh .agents/bin/test; sh .agents/bi""n/test\n),
    '.agents/run.rb' => %(system(File.expand_path("bin/validate", __dir__))\n),
    'lib/app.rb' => %(system(File.join(app_home, ".agents", "bin", "validate"))\n),
    'ci/docker.sh' => %(docker run -w .agents image ./bin/validate\n),
    '.agents/skills/plan/run.rb' =>
      %(system(File.expand_path(\n  "bin/validate",\n  File.expand_path("../..", __dir__)\n))\n),
    '.agents/run.sh' => %(cd "$(dirname "$0")" && bin/validate\n),
    'lib/wrapped.rb' => %(system("bin/validate",\n  chdir: ".agents")\n),
    'lib/wrapped.py' => %(subprocess.run(["bin/validate"],\n    cwd=".agents")\n),
    'lib/commented.py' => "subprocess.run([\"bin/validate\"],  # 1) validate files\n    cwd=\".agents\")\n",
    'spec/block_spec.rb' => %(Dir.chdir ".agents" do\n  system "bin/validate"\nend\n),
    'lib/back_out.rb' => %(cmd = File.join(root, ".agents", "shaka", "..", "bin", "validate")\n)
  }.freeze

  def test_nearby_real_references_still_block
    STILL_BLOCKED.each { |name, source| assert_file_blocked(name, source) }
  end

  def test_join_that_resolves_inside_the_new_layout_does_not_block
    assert_unblocked('spec/trust_test.rb',
                     %(config = File.join(root, ".agents", "shaka", "trusted-github-actors.yml")\n))
  end

  def test_join_that_resolves_to_a_moved_path_still_blocks
    assert_file_blocked('spec/trust_test.rb',
                        %(config = File.join(root, ".agents", "trusted-github-actors.yml")\n))
  end

  def test_machine_allowlist_under_home_does_not_block
    source = <<~RUBY
      HOME_CONFIG = "~/.agents/trusted-github-actors.yml"
      shell = "$HOME/.agents/trusted-github-actors.yml"
      machine = File.join(home, ".agents", "trusted-github-actors.yml")
      fixture = File.join(dir, "home", ".agents", "trusted-github-actors.yml")
      other = File.join(Dir.home, ".agents", "trusted-github-actors.yml")
    RUBY
    assert_unblocked('lib/trust.rb', source)
  end

  def test_regex_alternation_of_top_level_directories_does_not_block
    assert_unblocked('lib/risk.rb', %(roots = %r{\\A(\\.github/|\\.agents/|\\.claude/|bin/)}\n))
  end

  def test_assigned_unmoved_tool_does_not_block
    assert_unblocked('ci/safety.test.cjs', %(const agentLint = read('.agents/bin/lint');\n))
    assert_unblocked('ci/run.sh', "args=(.agents/bin/lint .agents/shaka/bin/setup .agents/shaka/bin/test)\n")
  end

  def test_assigned_moved_command_still_blocks
    assert_file_blocked('ci/safety.test.cjs', %(const agentValidate = read('.agents/bin/validate');\n))
  end

  def test_old_directory_and_command_on_different_lines_do_not_block
    source = <<~RUBY
      links = {
        ".agents" => "agent-tool"
      }
      describe "bin/setup" do
      end
    RUBY
    assert_unblocked('spec/setup_spec.rb', source)
  end

  def test_old_directory_and_command_on_one_line_still_block
    assert_file_blocked('spec/setup_spec.rb', %(Dir.chdir(".agents") { system("bin/test") }\n))
  end

  def test_nested_layout_file_naming_the_repository_bin_does_not_block
    source = <<~RUBY
      #!/usr/bin/env ruby
      # Set by bin/validate in this source pack.
      ROOT = File.expand_path(__dir__)
      CHECKS = { "automated_checks" => "bin/validate" }.freeze
    RUBY
    assert_unblocked('.agents/skills/plan/scripts/check.rb', source)
  end

  def test_nested_layout_file_building_a_command_path_still_blocks
    source = %(#!/usr/bin/env ruby\nsystem(File.join(__dir__, "..", "..", "bin", "validate"))\n)
    assert_file_blocked('.agents/skills/plan/run.rb', source)
  end
end

# A repository that keeps its own tools in the old command directory while Shaka's wrappers move.
class SeamUpgradeRetainedToolRoutingTest < Minitest::Test
  include SeamUpgradeFileBlockers

  REAL_ALIASES = [
    %(#!/bin/sh\nPATH=".agents/bin:$PATH"\nvalidate\n),
    %(#!/bin/sh\ncd .agents/bin && ./validate\n),
    %(#!/bin/sh\ncd .agents/bin\n),
    "#!/bin/sh\ncase \"$1\" in\n  .agents/bin/*|.agents/shaka/bin/lint) echo ci ;;\nesac\n",
    "#!/bin/sh\ncase \"$1\" in\n  .agents/bin/*|.agents/shaka/bin/[l]*) echo ci ;;\nesac\n",
    %(#!/usr/bin/env ruby\nsystem(".agents/bin/" + name)\n),
    %(#!/usr/bin/env node\nexecSync('.agents/bin/' + process.argv[2])\n),
    %(#!/usr/bin/env ruby\nsystem(".agents/bin/\#{name}")\n),
    %(#!/usr/bin/env python3\nsubprocess.run([Path(".agents/bin") / cmd])\n),
    "#!/bin/sh\ncase \"$1\" in\n  .agents/shaka/*) echo docs ;;\n  " \
    ".agents/bin/*|.agents/shaka/bin/*) echo ci ;;\nesac\n"
  ].freeze

  DETECTOR = <<~SHELL
    #!/bin/sh
    # Keep this before the broader .agents/** arm.
    case "$1" in
      .agents/bin/*.md|.agents/shaka/*.md) echo docs ;;
      .agents/bin/*|.agents/bin/**/*|.agents/shaka/bin/*|.agents/shaka/bin/**/*) echo ci ;;
      .agents/*|.agents/**/*) echo docs ;;
    esac
  SHELL

  def test_routing_beside_retained_tools_does_not_block
    with_retained_tool do |root|
      write_executable(root, 'script/detector', DETECTOR)
      write_executable(root, 'script/detector-test', "#!/bin/sh\nmkdir -p .agents/bin\necho > .agents/bin/lint\n")
      blockers = plan_for(root).blockers
      assert_empty(blockers.grep(/script/), blockers.join("\n"))
    end
  end

  def test_command_directory_glob_that_misses_the_new_directory_still_blocks
    with_retained_tool do |root|
      write_executable(root, 'script/detector', "#!/bin/sh\ncase \"$1\" in\n  .agents/bin/*) echo ci ;;\nesac\n")
      assert_blocked_with(root, 'script/detector: old command-directory reference')
    end
  end

  def test_real_aliases_of_the_command_directory_still_block
    REAL_ALIASES.each do |source|
      with_retained_tool do |root|
        write_executable(root, 'script/run', source)
        assert_includes(plan_for(root).blockers.join, 'script/run:', source)
      end
    end
  end

  private

  def with_retained_tool
    with_repository do |root, parent|
      write_executable(root, '.agents/bin/lint', "#!/bin/sh\necho lint\n")
      yield root, parent
    end
  end

  def write_executable(root, name, source)
    path = write_tracked(root, name, source)
    File.chmod(0o755, path)
    commit_fixture(root, "#{name} mode")
  end
end
