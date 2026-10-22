# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/seam_upgrade_fixture'

# Shapes seen in real repositories that keep their meaning after the upgrade.
class SeamUpgradeUnmovedToolTest < Minitest::Test
  include SeamUpgradeFixture

  README = Class.new do
    include Shaka::Seam::InitializerReadme

    public :readme_source
  end.new

  ROOT_TOOLS = {
    'inline root cd' => %(#!/bin/sh\nset -eu\ncd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"\n) +
                        %(exec bin/probe\n),
    'root assignment' => %(#!/bin/sh\nset -eu\nroot="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"\n) +
                         %(exec "$root/bin/probe"\n),
    'Ruby root' => %(#!/usr/bin/env ruby\nroot = File.expand_path("../..", __dir__)\nputs root\n),
    'require outside the command directory' => %(#!/usr/bin/env ruby\nrequire_relative "../skills/helper/lib/probe"\n),
    'require an unmoved sibling' => %(#!/usr/bin/env ruby\nrequire_relative "formatter_support"\n)
  }.freeze

  SIBLING_TOOLS = {
    'dirname sibling' => %(#!/bin/sh\nexec "$(dirname "$0")/test"\n),
    'root then sibling' => %(#!/bin/sh\ncd "$(dirname "$0")/../.."\nexec "$(dirname "$0")/validate"\n),
    'require a moved sibling' => %(#!/usr/bin/env ruby\nrequire_relative "validate"\n)
  }.freeze

  def test_unmoved_tool_finding_the_root_does_not_block
    ROOT_TOOLS.each do |name, source|
      with_repository do |root|
        write_tool(root, 'formatter', source)
        preview = report(root)
        refute(preview.fetch('blockers').any? { |item| item.include?('formatter') }, name)
      end
    end
  end

  def test_unmoved_tool_reaching_a_moved_sibling_blocks
    SIBLING_TOOLS.each_value do |source|
      with_repository do |root|
        write_tool(root, 'formatter', source)
        assert_blocked_with(root, '.agents/bin/formatter: tool uses an invocation-relative path')
      end
    end
  end

  def test_nested_tool_two_levels_up_still_blocks
    with_repository do |root|
      write_tool(root, 'sub/formatter', %(#!/bin/sh\ncd "$(dirname "$0")/../.."\nexec bin/validate\n))
      assert_blocked_with(root, '.agents/bin/sub/formatter: tool uses an invocation-relative path')
    end
  end

  def test_generated_pointer_is_rewritten_beside_retained_tools
    with_repository do |root|
      write_tool(root, 'build', "#!/bin/sh\necho ok\n")
      path = write_tracked(root, '.agents/shaka.md', README.readme_source(Shaka::Configuration::Layout::LEGACY))
      assert_equal 'applied', apply_upgrade(root).fetch('status')
      assert_equal README.readme_source(Shaka::Configuration::Layout::NEW), File.read(path)
    end
  end

  def test_hand_written_note_beside_retained_tools_still_blocks
    with_repository do |root|
      write_tool(root, 'build', "#!/bin/sh\necho ok\n")
      write_tracked(root, '.agents/docs/notes.md', "Wrappers live in `../bin/`.\n")
      assert_blocked_with(root, '.agents/docs/notes.md: relative old-layout reference ../bin/')
    end
  end

  def test_markdown_link_leaving_the_layout_is_unchanged
    source = "See [.agents/workflows/x.md](../../.agents/workflows/x.md).\n" \
             "See [`.agents/docs/a.md`](../../.agents/docs/a.md), too.\n" \
             '**[.agents/workflows/x.md](../../.agents/workflows/x.md)** and ' \
             "![.agents/a.png](../../.agents/a.png)\n"
    with_repository do |root|
      path = write_tracked(root, '.claude/prompts/review.md', source)
      assert_equal 'applied', apply_upgrade(root).fetch('status')
      assert_equal source, File.read(path)
    end
  end

  def test_parent_traversal_inside_the_layout_still_blocks
    ['workflows', 'cache[1]', 'cache](1)', 'cache[1](2)', 'cache+[1](2)', 'x([1](2)'].each do |directory|
      with_repository do |root|
        write_tracked(root, ".agents/#{directory}/.keep", '') if directory.include?('](')
        write_tracked(root, 'docs/run.md', "Run .agents/#{directory}/../bin/test first; see [guide](guide.md).\n")
        assert_blocked_with(root, 'docs/run.md: normalized old-layout reference')
      end
    end
  end

  def test_parent_traversal_beside_a_link_still_blocks
    ['See [guide](guide.md).agents/workflows/../bin/test now.',
     'See [.agents/workflows/../bin/test](../guide.md).'].each do |line|
      with_repository do |root|
        write_tracked(root, 'docs/run.md', "#{line}\n")
        assert_blocked_with(root, 'docs/run.md: normalized old-layout reference')
      end
    end
  end

  private

  def write_tool(root, name, source)
    path = File.join(root, '.agents/bin', name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, source)
    File.chmod(0o755, path)
    commit_fixture(root, name)
  end
end
