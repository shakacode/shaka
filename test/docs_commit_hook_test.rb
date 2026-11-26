# frozen_string_literal: true

require_relative 'support/docs_navigation_fixture'

class DocsCommitHookTest < Minitest::Test
  include DocsNavigationFixture

  ROOT = File.expand_path('..', __dir__)

  def test_hook_checks_all_markdown_extensions_and_preserves_contributor_destinations
    %w[new-guides/install.mdx new-guides/install.MDX new-guide.MdX contributing/install.MDX].each do |path|
      output, errors, status = hook_fixture(path)
      allowed = path.start_with?('contributing/')
      assert_equal allowed, status.success?, "#{path}: #{output}\n#{errors}"
      assert_includes output, "Markdown outside established documentation locations: #{path}" unless allowed
    end
  end

  def test_partial_staging_checks_the_index_and_preserves_unstaged_work
    output, errors, status = check('docsSidebar' => ['expected-experience']) do |root|
      install_hook_fixture(root)
      staged, working = stage_partial_guide(root)
      assert_partial_staging(root, staged, working)
    end
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end

  private

  def hook_fixture(path)
    result = nil
    check('docsSidebar' => ['expected-experience']) do |root|
      install_hook_fixture(root)
      stage_document(root, path)
      result = run_hook(root)
    end
    result
  end

  def run_hook(root)
    Open3.capture3({ 'BUNDLE_GEMFILE' => File.join(root, 'Gemfile'), 'LEFTHOOK_CONFIG' => nil },
                   'bundle', 'exec', 'lefthook', 'run', 'pre-commit', '--no-auto-install', '--no-tty', chdir: root)
  end

  def stage_partial_guide(root)
    path = File.join(root, 'docs/expected-experience.md')
    staged = "# Guide\n[Agent](https://github.com/shakacode/shaka/blob/main/skills/shaka/config/work-prompt.md)\n"
    working = "# Guide\n"
    File.write(path, staged)
    system('git', '-C', root, 'add', 'docs/expected-experience.md', exception: true)
    File.write(path, working)
    [staged, working]
  end

  def assert_partial_staging(root, staged, working)
    output, errors, status = run_hook(root)
    refute_predicate status, :success?, "#{output}\n#{errors}"
    assert_includes output, 'Link a human guide, not agent instructions:'
    assert_equal working, File.read(File.join(root, 'docs/expected-experience.md'))
    actual, = Open3.capture2('git', '-C', root, 'show', ':docs/expected-experience.md')
    assert_equal staged, actual
  end

  def install_hook_fixture(root)
    FileUtils.mkdir_p([File.join(root, 'bin'), File.join(root, 'lib')])
    %w[Gemfile Gemfile.lock .lefthook.yml bin/check-docs-navigation].each do |source|
      FileUtils.cp(File.join(ROOT, source), File.join(root, source))
    end
    %w[lib/shaka_docs bin/lefthook].each { |source| FileUtils.cp_r(File.join(ROOT, source), File.join(root, source)) }
    system('git', '-C', root, 'add', '.', exception: true)
    commit_fixture(root)
  end

  def commit_fixture(root)
    args = %w[-c user.name=TestUser -c user.email=test@example.com -c commit.gpgsign=false]
    system('git', '-C', root, *args, 'commit', '--no-verify', '-qm', 'Hook fixture', exception: true)
  end

  def stage_document(root, path)
    FileUtils.mkdir_p(File.dirname(File.join(root, path)))
    File.write(File.join(root, path), "# Install\n")
    system('git', '-C', root, 'add', path, exception: true)
  end
end
