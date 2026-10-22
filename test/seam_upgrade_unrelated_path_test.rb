# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/seam_upgrade_fixture'

class SeamUpgradeUnrelatedPathTest < Minitest::Test
  include SeamUpgradeFixture

  def test_assignment_to_unrelated_agents_path_is_ready
    with_repository do |root|
      path = write_tracked(root, 'scripts/run-demo', "#!/bin/sh\nDEMO=\".agents/skills/demo/run\"\nexec \"$DEMO\"\n")
      File.chmod(0o755, path)
      commit_fixture(root, 'executable demo')
      preview = report(root)
      assert_equal 'ready', preview.fetch('status'), preview.fetch('blockers').join("\n")
    end
  end

  MOVED_PATH_ASSIGNMENTS = {
    'normalized directory' => "#!/bin/sh\ndir=.agents/.\ncommand=test\nexec \"$dir/bin/$command\"\n",
    'repeated separator' => "#!/bin/sh\ndir=.agents//\ncommand=test\nexec \"$dir/bin/$command\"\n",
    'allowlist' => "#!/bin/sh\nactors=.agents/trusted-github-actors.yml\ncat \"$actors\"\n",
    'command directory' => "#!/bin/sh\nhelpers=.agents/bin\nexec \"$helpers/test\"\n",
    'command' => "#!/bin/sh\nrunner=$ROOT/.agents/bin/test\nexec \"$runner\"\n",
    'contract' => "#!/bin/sh\nconfig=\"$ROOT/.agents/agent-workflow.yml\"\ncat \"$config\"\n"
  }.freeze

  def test_assignment_to_moved_path_still_blocks
    MOVED_PATH_ASSIGNMENTS.each do |name, source|
      with_repository do |root|
        write_tracked(root, 'ci.sh', source)
        assert_equal 'blocked', report(root).fetch('status'), name
      end
    end
  end

  MOVED_PATH_PROSE = "Settings live in `.agents/agent-workflow.yml`.\n"

  def test_unrelated_continuation_in_markdown_does_not_block_moved_path
    with_repository do |root|
      source = "#{MOVED_PATH_PROSE}\n```sh\nrun-demo \\\n  --verbose\n```\n"
      write_tracked(root, 'guide.md', source)
      preview = report(root)
      assert_equal 'ready', preview.fetch('status'), preview.fetch('blockers').join("\n")
    end
  end

  def test_path_split_by_continuation_still_blocks
    with_repository do |root|
      write_tracked(root, 'ci.sh', "#!/bin/sh\necho start \\\n  done\nexec .agents/bi\\\nn/test\n")
      assert_blocked_with(root, 'continued old-layout reference')
    end
  end
end
