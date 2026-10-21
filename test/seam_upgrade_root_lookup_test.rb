# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/seam_upgrade_fixture'

class SeamUpgradeRootLookupTest < Minitest::Test
  include SeamUpgradeFixture

  ROOT_WRAPPERS = {
    'quoted dirname' => %(#!/bin/sh\nset -eu\nroot="$(dirname -- "$0")/../.."\n),
    'cd and pwd' => %(#!/bin/sh\nset -eu\nroot=$(cd "$(dirname "$0")/../.." && pwd)\n),
    'quoted cd and pwd' => %(#!/bin/sh\nset -eu\nroot="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"\n),
    'bash source' => %(#!/bin/bash\nset -euo pipefail\nroot="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"\n)
  }.freeze

  INLINE_WRAPPERS = {
    'inline cd' => %(#!/bin/sh\nset -eu\ncd "$(dirname "$0")/../.."\n),
    'inline cd with bash source' => %(#!/bin/bash\nset -e\ncd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."\n)
  }.freeze

  def test_common_root_assignments_are_repaired
    ROOT_WRAPPERS.each do |name, head|
      assert_repaired_wrapper(name, "#{head}cd \"$root\"\nexec \"$root/bin/probe\" \"$@\"\n")
    end
  end

  def test_inline_root_changes_are_repaired
    INLINE_WRAPPERS.each do |name, head|
      assert_repaired_wrapper(name, "#{head}exec bin/probe \"$@\"\n")
    end
  end

  def test_inline_cd_before_exit_on_error_is_blocked
    with_repository do |root|
      write_wrapper(root, 'setup', %(#!/bin/sh\ncd "$(dirname "$0")/../.."\nset -e\nexec bin/probe\n))
      commit_fixture(root, 'late errexit')
      assert_blocked_with(root, 'ambiguous repository-root')
    end
  end

  def test_inline_cd_keeps_an_existing_root_variable
    with_repository do |root|
      source = %(#!/bin/sh\nset -eu\nroot=/elsewhere\ncd "$(dirname "$0")/../.."\nexec bin/probe "$root"\n)
      write_wrapper(root, 'setup', source)
      commit_fixture(root, 'existing root variable')
      assert_blocked_with(root, 'ambiguous repository-root calculation; repair it explicitly')
    end
  end

  def test_root_lookup_under_another_name_reports_the_exact_replacement
    with_repository do |root|
      write_wrapper(root, 'setup', %(#!/bin/sh\nset -eu\nrepo_root="$(cd "$(dirname "$0")/../.." && pwd)"\n))
      commit_fixture(root, 'renamed root')
      assert_blocked_with(root, "repo_root=#{Shaka::Seam::UpgradePlan::GIT_ROOT.delete_prefix('root=')}")
    end
  end

  def test_second_parent_path_after_a_repaired_root_blocks
    [%(root=$(cd "$(dirname "$0")/../.." && pwd)), SeamUpgradeFixture::ROOT_LINE].each do |line|
      with_repository do |root|
        write_wrapper(root, 'setup', %(#!/bin/sh\nset -eu\n#{line}\ncd "$root/../.."\n))
        commit_fixture(root, 'second parent path')
        assert_blocked_with(root, 'ambiguous repository-root calculation; repair it explicitly')
      end
    end
  end

  def test_other_parent_paths_get_no_replacement
    [%(assets="$(dirname "$0")/../../assets"), %(cd "$(dirname "$0")/../.." && make)].each do |line|
      with_repository do |root|
        write_wrapper(root, 'setup', "#!/bin/sh\nset -eu\n#{line}\n")
        commit_fixture(root, 'other parent path')
        assert_blocked_with(root, 'ambiguous repository-root calculation; repair it explicitly')
      end
    end
  end

  def test_exported_root_gets_no_replacement_that_drops_export
    with_repository do |root|
      write_wrapper(root, 'setup', %(#!/bin/sh\nset -eu\nexport ROOT="$(dirname "$0")/../.."\n))
      commit_fixture(root, 'exported root')
      assert_blocked_with(root, 'ambiguous repository-root calculation; repair it explicitly')
    end
  end

  private

  def assert_repaired_wrapper(name, source)
    with_repository do |root, parent|
      write_wrapper(root, 'setup', source)
      commit_fixture(root, name)
      before = probe_output(root, '.agents/bin/setup', parent)
      assert_equal 'applied', apply_upgrade(root).fetch('status'), name
      assert_equal before, probe_output(root, '.agents/shaka/bin/setup', parent), name
    end
  end

  def probe_output(root, command, parent)
    output, error, status = Open3.capture3(File.join(root, command), 'one', chdir: parent)
    assert_predicate status, :success?, error
    normalized_output(output)
  end
end
