# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require_relative 'cli_opening_check_fakes'
require 'json'

class CliOpeningInterpreterTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Pull requests explain the outcome first.'

  def test_gh_wrapper_cannot_use_candidate_backed_interpreter
    with_repository do |root|
      commit(root)
      Dir.mktmpdir { |dir| assert_gh_interpreter_safe(dir, root, '#!/usr/bin/env node') }
    end
  end

  def test_env_split_string_skips_assignments_before_interpreter
    with_repository do |root|
      commit(root)
      Dir.mktmpdir { |dir| assert_gh_interpreter_safe(dir, root, '#!/usr/bin/env -S FOO=1 node') }
    end
  end

  def test_env_attached_split_string_names_interpreter
    with_repository do |root|
      commit(root)
      Dir.mktmpdir { |dir| assert_gh_interpreter_safe(dir, root, '#!/usr/bin/env -Snode') }
    end
  end

  private

  def assert_gh_interpreter_safe(dir, root, shebang)
    external, safe = make_bins(dir)
    marker = File.join(dir, 'candidate-node-called')
    add_candidate_node(root, external, marker)
    write_executable(safe, 'gh', fake_gh)
    with_path(safe) do
      assert_safe_publication(external, root, marker, shebang)
    end
  end

  def assert_safe_publication(external, root, marker, shebang)
    output, error, status = run_description(external, root:) { |bin| use_env_node(bin, shebang) }
    assert_predicate status, :success?, error
    assert_equal 'host_check', JSON.parse(output).dig('opening', 'status')
    assert_path_exists File.join(external, 'published.md')
    refute_path_exists marker
  end

  def make_bins(dir)
    %w[external safe].map { |name| File.join(dir, name).tap { |path| Dir.mkdir(path) } }
  end

  def add_candidate_node(root, external, marker)
    target = File.join(root, 'node')
    File.write(target, "#!/bin/sh\ntouch #{marker}\nexit 1\n")
    File.chmod(0o755, target)
    File.symlink(target, File.join(external, 'node'))
  end

  def use_env_node(bin, shebang)
    gh = File.join(bin, 'gh')
    File.write(gh, File.read(gh).sub(/\A#![^\n]+/, shebang))
  end

  def with_path(bin)
    original = ENV.fetch('PATH')
    ENV['PATH'] = "#{bin}:#{original}"
    yield
  ensure
    ENV['PATH'] = original
  end
end
