# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/seam_upgrade_fixture'

class SeamUpgradeMarkdownProseTest < Minitest::Test
  include SeamUpgradeFixture

  SEPARATE_PARAGRAPHS = "Shaka kept settings in the `.agents/` directory.\n\n" \
                        "Later, CI ran `bin/validate` on every push.\n"

  def test_directory_and_command_in_separate_paragraphs_are_ready
    with_repository do |root|
      write_tracked(root, 'ledger.md', SEPARATE_PARAGRAPHS)
      preview = report(root)
      assert_equal 'ready', preview.fetch('status'), preview.fetch('blockers').join("\n")
    end
  end

  def test_quoted_command_directory_in_prose_is_rewritten
    with_repository do |root|
      path = write_tracked(root, 'ledger.md', "Wrappers live in `.agents/bin/`.\n")
      preview = report(root)
      assert_equal 'ready', preview.fetch('status'), preview.fetch('blockers').join("\n")
      apply_upgrade(root)
      assert_equal "Wrappers live in `.agents/shaka/bin/`.\n", File.read(path)
    end
  end

  def test_prose_after_crlf_fence_is_rewritten
    with_repository do |root|
      path = write_tracked(root, 'ledger.md', "```text\r\nexample\r\n```\r\nWrappers live in `.agents/bin/`.\r\n")
      preview = report(root)
      assert_equal 'ready', preview.fetch('status'), preview.fetch('blockers').join("\n")
      apply_upgrade(root)
      assert_includes File.read(path), 'Wrappers live in `.agents/shaka/bin/`.'
    end
  end

  def test_computed_command_directory_in_prose_still_blocks
    with_repository do |root|
      write_tracked(root, 'ledger.md', "Add `$PWD/.agents/bin` to PATH.\n")
      assert_blocked_with(root, 'old command-directory reference')
    end
  end

  MARKDOWN_CODE = {
    'fenced sh' => "Setup:\n\n```sh\ncd .agents\nbin/validate\n```\n",
    'fenced bash' => "Setup:\n\n~~~bash\ncd .agents && bin/validate\n~~~\n",
    'indented' => "Setup:\n\n    cd .agents\n    bin/validate\n",
    'quoted fence' => "> Setup:\n>\n> ```sh\n> cd .agents\n> bin/validate\n> ```\n",
    'list fence' => "1. ```sh\n   cd .agents\n   bin/validate\n   ```\n",
    'inline code' => "Run `cd .agents && bin/validate` before pushing.\n",
    'inline env' => "Run `env -C .agents bin/validate`.\n",
    'same line' => "Run `bin/validate` from `.agents`.\n"
  }.freeze

  def test_shell_code_in_markdown_still_blocks
    MARKDOWN_CODE.each do |name, source|
      with_repository do |root|
        write_tracked(root, 'guide.md', source)
        blockers = report(root).fetch('blockers').join("\n")
        assert_includes blockers, 'bare old-layout directory', name
      end
    end
  end

  def test_fenced_command_directory_still_blocks
    with_repository do |root|
      write_tracked(root, 'guide.md', "```sh\nexport PATH=\".agents/bin:$PATH\"\n```\n")
      assert_blocked_with(root, 'old command-directory reference')
    end
  end

  def test_shell_script_with_directory_and_command_still_blocks
    with_repository do |root|
      write_tracked(root, 'ci.sh', "#!/bin/sh\ncd .agents\nbin/validate\n")
      assert_blocked_with(root, 'bare old-layout directory')
    end
  end

  def test_executable_markdown_keeps_whole_file_check
    with_repository do |root|
      path = File.join(root, 'check.md')
      File.write(path, SEPARATE_PARAGRAPHS)
      File.chmod(0o755, path)
      commit_fixture(root, 'executable markdown')
      assert_blocked_with(root, 'bare old-layout directory')
    end
  end
end
