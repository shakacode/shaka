# frozen_string_literal: true

require_relative 'support/docs_navigation_fixture'

class DocsFixtureIsolationTest < Minitest::Test
  include DocsNavigationFixture

  def test_inherited_git_routing_cannot_change_the_outer_index
    output, errors, status = check('docsSidebar' => ['expected-experience']) { |outer| assert_outer_preserved(outer) }
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end

  def test_runtime_git_configuration_cannot_change_the_outer_index
    check('docsSidebar' => ['expected-experience']) do |outer|
      before = prepare_outer(outer)
      with_runtime_config(outer) { assert_runtime_isolated(outer) }
      assert_equal before, File.binread(File.join(outer, '.git/index'))
    end
  end

  def assert_runtime_isolated(outer)
    global = ENV.fetch('GIT_CONFIG_GLOBAL')
    output, errors, status = check('docsSidebar' => ['expected-experience']) do |inner|
      assert_nil ENV.fetch('GIT_CONFIG_COUNT', nil)
      assert_equal global, ENV.fetch('GIT_CONFIG_GLOBAL')
      system('git', '-C', inner, 'add', '.', exception: true)
    end
    assert_predicate status, :success?, "#{output}\n#{errors}"
    assert_equal '1', ENV.fetch('GIT_CONFIG_COUNT')
    assert_equal outer, ENV.fetch('GIT_CONFIG_VALUE_0')
  end

  def with_runtime_config(root)
    config = { 'GIT_CONFIG_COUNT' => '1', 'GIT_CONFIG_KEY_0' => 'core.worktree', 'GIT_CONFIG_VALUE_0' => root }
    saved = config.to_h { |name, value| [name, ENV.fetch(name, nil)].tap { ENV[name] = value } }
    yield
  ensure
    saved.each { |name, value| ENV[name] = value }
  end

  def assert_outer_preserved(root)
    before = prepare_outer(root)
    with_routing(root) { assert_isolated_fixture(root) }
    assert_equal before, File.binread(File.join(root, '.git/index'))
  end

  def prepare_outer(root)
    File.write(File.join(root, 'sentinel'), 'Preserve this index')
    system('git', '-C', root, 'add', 'sentinel', exception: true)
    File.binread(File.join(root, '.git/index'))
  end

  def assert_isolated_fixture(outer)
    output, errors, status = check('docsSidebar' => ['expected-experience']) do |root|
      assert(GIT_ROUTING.all? { |name| ENV[name].nil? })
      system('git', '-C', root, 'add', '.', exception: true)
    end
    assert_predicate status, :success?, "#{output}\n#{errors}"
    assert_equal File.join(outer, '.git'), ENV.fetch('GIT_DIR')
  end

  def with_routing(root)
    routing = { 'GIT_DIR' => '.git', 'GIT_WORK_TREE' => '.', 'GIT_INDEX_FILE' => '.git/index',
                'GIT_COMMON_DIR' => '.git', 'GIT_OBJECT_DIRECTORY' => '.git/objects' }
    saved = routing.to_h { |name, value| [name, ENV.fetch(name, nil)].tap { ENV[name] = File.join(root, value) } }
    yield
  ensure
    saved.each { |name, value| ENV[name] = value }
  end
end

class DocsFixtureSymlinkCapabilityTest < Minitest::Test
  include DocsNavigationFixture

  def test_unavailable_symlinks_skip_and_restore_the_fixture_environment
    before = ENV.to_h.slice(*GIT_ROUTING)
    repository = nil
    with_denied_symlinks do
      assert_raises(Minitest::Skip) do
        check('docsSidebar' => ['expected-experience']) { |root| create_unavailable_link(repository = root) }
      end
    end
    refute_path_exists repository
    assert_equal before, ENV.to_h.slice(*GIT_ROUTING)
  end

  private

  def create_unavailable_link(root)
    create_symlink('missing.md', File.join(root, 'docs/link.md'))
  end

  def with_denied_symlinks
    original = File.method(:symlink)
    File.define_singleton_method(:symlink) { |*| raise Errno::EPERM }
    yield
  ensure
    File.define_singleton_method(:symlink, original)
  end
end

class DocsCaseInventoryTest < Minitest::Test
  include DocsNavigationFixture

  def test_third_party_cdn_file_paths_do_not_identify_the_source_repository
    page = '[Guide](https://cdn.jsdelivr.net/gh/example/other@main/' \
           'examples/shakacode/shaka/skills/shaka/references/guide.md)'
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    assert_predicate status, :success?, output
  end

  def test_cdn_repository_paths_get_the_same_agent_classification
    paths = %w[skills/shaka/config/review-prompt.md .agents/shaka/instructions/review.md]
    paths.each do |path|
      page = "[Guide](https://cdn.jsdelivr.net/gh/shakacode/shaka@main/#{path})"
      output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
      refute_predicate status, :success?
      assert_includes output, 'Link a human guide, not agent instructions:'
    end
  end

  def test_first_party_reference_urls_are_not_limited_to_github_hosts
    page = '[Review](https://cdn.jsdelivr.net/gh/shakacode/shaka@main/skills/shaka/references/review.md)'
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    refute_predicate status, :success?
    assert_includes output, 'Link a human guide, not agent instructions:'
    page = '[Guide](https://cdn.jsdelivr.net/gh/example/other@main/skills/shaka/references/review.md)'
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    assert_predicate status, :success?, output
  end

  def test_uppercase_markdown_requires_a_destination_in_git_and_exports
    paths = %w[new-guides/INSTALL.MD new-guides/install.MdX]
    paths.product([true, false]).each do |path, git|
      output, _, status = uppercase_fixture(path, git)
      refute_predicate status, :success?, "#{git}: #{path}"
      assert_includes output, "Markdown outside established documentation locations: #{path}"
    end
  end

  def test_uppercase_markdown_can_have_an_established_non_site_destination
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide',
                              'contributing/INSTALL.MD' => '# Install')
    assert_predicate status, :success?, output
  end

  private

  def uppercase_fixture(path, git)
    check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', path => '# Install') do |root|
      if git
        system('git', '-C', root, 'add', path, exception: true)
      else
        FileUtils.remove_entry(File.join(root, '.git'))
      end
    end
  end
end

class DocsIgnoredInventoryTest < Minitest::Test
  include DocsNavigationFixture

  def test_ignored_docs_are_skipped_until_tracked
    files = { '.gitignore' => "/docs/.cache/\n", 'docs/.cache/README.md' => '[Generated](missing.md)' }
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', files)
    assert_predicate status, :success?, output
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', files) do |root|
      system('git', '-C', root, 'add', '-f', 'docs/.cache/README.md', exception: true)
    end
    refute_predicate status, :success?
    assert_includes output, 'Site-excluded Markdown: .cache/README.md'
    assert_includes output, 'docs/.cache/README.md -> missing.md (missing file)'
  end
end

class DocsSymlinkAudienceTest < Minitest::Test
  include DocsNavigationFixture

  def test_enrolled_product_guides_cannot_alias_agent_procedures
    files = { 'skills/shaka/references/procedure.txt' => '# Agent procedure' }
    _, errors, status = check({ 'docsSidebar' => %w[expected-experience procedure] }, '# Guide', files) do |root|
      create_symlink('../skills/shaka/references/procedure.txt', File.join(root, 'docs/procedure.md'))
      system('git', '-C', root, 'add', 'docs/procedure.md', exception: true)
    end
    refute_predicate status, :success?
    assert_includes errors, 'Docs sources cannot be symlinks: docs/procedure.md'
  end

  def test_dangling_guides_are_rejected_in_source_exports
    _, errors, status = check('docsSidebar' => ['expected-experience']) do |root|
      FileUtils.remove_entry(File.join(root, '.git'))
      create_symlink('missing.md', File.join(root, 'docs/broken.md'))
    end
    refute_predicate status, :success?
    assert_includes errors, 'Docs sources cannot be symlinks: docs/broken.md'
  end

  def test_directories_cannot_alias_agent_procedures
    _, errors, status = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide',
                              'skills/shaka/references/procedure.txt' => '# Agent') do |root|
      create_symlink(File.join(root, 'skills/shaka/references'), File.join(root, 'docs/procedures'))
    end
    refute_predicate status, :success?
    assert_includes errors, 'Docs sources cannot be symlinks: docs/procedures'
  end
end

class DocsSymlinkBoundaryTest < Minitest::Test
  include DocsNavigationFixture

  def test_docs_root_is_checked_before_reading_its_sidebar
    _, errors, status = check('docsSidebar' => ['expected-experience']) do |root|
      alias_docs_root(root)
    end
    refute_predicate status, :success?
    assert_includes errors, 'Docs sources cannot be symlinks: docs'
  end

  def test_dangling_sidebar_is_refused_before_reading_its_target
    _, errors, status = check('docsSidebar' => ['expected-experience']) do |root|
      path = File.join(root, 'docs/sidebars.json')
      File.unlink(path)
      create_symlink('missing.json', path)
    end
    refute_predicate status, :success?
    assert_includes errors, 'Docs sources cannot be symlinks: docs/sidebars.json'
  end

  def test_dangling_non_markdown_skill_alias_is_not_an_emitted_link_source
    output, errors, status = check('docsSidebar' => ['expected-experience']) do |root|
      directory = File.join(root, 'skills/example')
      FileUtils.mkdir_p(directory)
      create_symlink('missing.txt', File.join(directory, 'procedure.txt'))
    end
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end

  def test_ignored_svg_alias_is_skipped_until_tracked
    output, errors, status = svg_alias(tracked: false)
    assert_predicate status, :success?, "#{output}\n#{errors}"
    _, errors, status = svg_alias(tracked: true)
    refute_predicate status, :success?
    assert_includes errors, 'Docs sources cannot be symlinks: docs/img/local.svg'
  end

  def test_ignored_directory_alias_above_a_tracked_guide_is_refused
    files = { '.gitignore' => "/docs/guides\n", 'docs/guides/install.md' => '# Install' }
    sidebar = { 'docsSidebar' => %w[expected-experience guides/install] }
    _, errors, status = check(sidebar, '# Guide', files) { |root| alias_tracked_directory(root) }
    refute_predicate status, :success?
    assert_includes errors, 'Docs sources cannot be symlinks: docs/guides'
  end

  def test_ignored_alias_above_a_missing_tracked_asset_is_refused
    files = { '.gitignore' => "/docs/img/figures\n", 'docs/img/figures/chart.svg' => '<svg/>' }
    _, errors, status = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', files) do |root|
      alias_missing_asset(root)
    end
    refute_predicate status, :success?
    assert_includes errors, 'Docs sources cannot be symlinks: docs/img/figures'
  end

  def test_deleted_tracked_asset_under_a_regular_directory_is_not_a_symlink
    files = { 'docs/img/chart.svg' => '<svg/>' }
    output, errors, status = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', files) do |root|
      system('git', '-C', root, 'add', 'docs/img/chart.svg', exception: true)
      File.unlink(File.join(root, 'docs/img/chart.svg'))
    end
    assert_predicate status, :success?, "#{output}\n#{errors}"
  end

  private

  def alias_missing_asset(root)
    system('git', '-C', root, 'add', '-f', 'docs/img/figures/chart.svg', exception: true)
    FileUtils.remove_entry(File.join(root, 'docs/img/figures'))
    FileUtils.mkdir_p(File.join(root, 'internal/empty-figures'))
    create_symlink(File.join(root, 'internal/empty-figures'), File.join(root, 'docs/img/figures'))
  end

  def alias_tracked_directory(root)
    system('git', '-C', root, 'add', '-f', 'docs/guides/install.md', exception: true)
    target = File.join(root, 'internal/guide-copy')
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.mv(File.join(root, 'docs/guides'), target)
    create_symlink(target, File.join(root, 'docs/guides'))
  end

  def svg_alias(tracked:)
    files = { '.gitignore' => "/docs/img/local.svg\n" }
    check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', files) do |root|
      directory = File.join(root, 'docs/img')
      FileUtils.mkdir_p(directory)
      create_symlink('missing.svg', File.join(directory, 'local.svg'))
      system('git', '-C', root, 'add', '-f', 'docs/img/local.svg', exception: true) if tracked
    end
  end

  def alias_docs_root(root)
    target = File.join(root, 'internal/actual-docs')
    FileUtils.mkdir_p(target)
    File.write(File.join(target, 'sidebars.json'), '{"docsSidebar":[]}')
    File.write(File.join(target, 'guide.md'), '# Unenrolled guide')
    FileUtils.remove_entry(File.join(root, 'docs'))
    create_symlink(target, File.join(root, 'docs'))
  end
end

class DocsExternalAliasTest < Minitest::Test
  include DocsNavigationFixture

  def test_outside_aliases_cannot_credit_ignored_docs
    %i[directory file].product([true, false]).each do |kind, present|
      target = kind == :directory ? '../internal/docs-alias/local.md#setup' : '../internal/file-alias.md#setup'
      files = { '.gitignore' => "/docs/local.md\n" }
      output, errors, status = check(
        { 'docsSidebar' => ['expected-experience'] }, "[Setup](#{target})", files
      ) { |root| install_alias(root, kind, present) }
      refute_predicate status, :success?, "#{output}\n#{errors}"
      assert_match(%r{Unresolved links in docs/ and skills/:|Source aliases are not supported:}, output + errors)
    end
  end

  private

  def install_alias(root, kind, present)
    FileUtils.mkdir_p(File.join(root, 'internal'))
    File.write(File.join(root, 'docs/local.md'), '# Setup') if present
    directory = kind == :directory
    target = directory ? File.join(root, 'docs') : '../docs/local.md'
    path = File.join(root, 'internal', directory ? 'docs-alias' : 'file-alias.md')
    assert File.directory?(target), 'Directory-link target must be an existing directory' if directory
    create_symlink(target, path)
    assert File.directory?(path), 'Directory alias must be traversable' if directory
  end
end

class DocsSkillSourceAliasTest < Minitest::Test
  include DocsNavigationFixture

  MARKER = 'https://github.com/shakacode/shaka/blob/main/docs/outside-only.md'

  def test_tracked_skill_sources_are_not_read_through_directory_aliases
    %w[rb md].each do |extension|
      output, errors, status = aliased_source(extension)
      refute_predicate status, :success?
      assert_includes errors, 'Source aliases are not supported: skills/example', output
      refute_includes output + errors, 'outside-only.md'
      output, _, status = regular_source(extension)
      refute_predicate status, :success?
      assert_includes output, 'outside-only.md (missing file)'
    end
  end

  def test_hidden_skill_file_aliases_are_not_read
    %w[rb md].each do |extension|
      output, errors, status = hidden_source_alias(extension)
      refute_predicate status, :success?
      assert_includes errors, 'Source aliases are not supported: skills/example/.local.', output
      refute_includes output + errors, 'outside-only.md'
      output, _, status = regular_source(extension, hidden: true)
      refute_predicate status, :success?
      assert_includes output, 'outside-only.md (missing file)'
    end
  end

  private

  def regular_source(extension, hidden: false)
    name = hidden ? '.local' : 'guide'
    check({ 'docsSidebar' => ['expected-experience'] }, '# Guide',
          "skills/example/#{name}.#{extension}" => MARKER)
  end

  def hidden_source_alias(extension)
    Dir.mktmpdir('outside-skill-file') do |outside|
      path = File.join(outside, "source.#{extension}")
      File.write(path, MARKER)
      check('docsSidebar' => ['expected-experience']) do |root|
        FileUtils.mkdir_p(File.join(root, 'skills/example'))
        create_symlink(path, File.join(root, "skills/example/.local.#{extension}"))
        system('git', '-C', root, 'add', 'skills/example', exception: true)
      end
    end
  end

  def aliased_source(extension)
    Dir.mktmpdir('outside-skill') do |outside|
      File.write(File.join(outside, "guide.#{extension}"), MARKER)
      files = { "skills/example/guide.#{extension}" => '# Regular source' }
      check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', files) do |root|
        system('git', '-C', root, 'add', 'skills/example', exception: true)
        FileUtils.remove_entry(File.join(root, 'skills/example'))
        create_symlink(outside, File.join(root, 'skills/example'))
      end
    end
  end
end

class DocsSparseCheckoutTest < Minitest::Test
  include DocsNavigationFixture

  def test_partial_checkouts_cannot_hide_a_tracked_guide
    %i[sparse skip].each do |mode|
      full, partial = partial_fixture(mode)
      assert_full_rejection(full)
      assert_partial_rejection(partial)
    end
  end

  private

  def partial_fixture(mode)
    full = nil
    files = { 'docs/hidden.md' => '# Hidden guide' }
    partial = check({ 'docsSidebar' => ['expected-experience'] }, '# Guide', files) do |root|
      commit_fixture(root)
      full = run_checker(root)
      hide_guide(root, mode)
    end
    [full, partial]
  end

  def run_checker(root)
    Open3.capture3('ruby', File.expand_path('../bin/check-docs-navigation', __dir__), File.join(root, 'docs'))
  end

  def assert_full_rejection(result)
    output, _, status = result
    refute_predicate status, :success?
    assert_includes output, 'Missing from docs/sidebars.json: hidden'
  end

  def assert_partial_rejection(result)
    _output, errors, status = result
    refute_predicate status, :success?
    assert_includes errors, 'Documentation validation requires a full checkout'
  end

  def hide_guide(root, mode)
    if mode == :sparse
      system('git', '-C', root, 'sparse-checkout', 'set', '--no-cone',
             '/docs/sidebars.json', '/docs/expected-experience.md', exception: true)
    else
      system('git', '-C', root, 'update-index', '--skip-worktree', 'docs/hidden.md', exception: true)
      File.unlink(File.join(root, 'docs/hidden.md'))
    end
  end

  def commit_fixture(root)
    system('git', '-C', root, 'add', '.', exception: true)
    args = %w[-c user.name=TestUser -c user.email=test@example.com -c commit.gpgsign=false]
    system('git', '-C', root, *args, 'commit', '--no-verify', '-qm', 'Sparse fixture', exception: true)
  end
end

class DocsIndexSymlinkTest < Minitest::Test
  include DocsNavigationFixture

  def test_committed_alias_is_refused_with_plain_file_checkout
    assert_checkout_refused(false)
  end

  def test_committed_alias_is_refused_with_real_symlink_checkout
    assert_checkout_refused(true)
  end

  private

  def assert_checkout_refused(symlinks)
    files = { 'skills/shaka/references/procedure.txt' => '# Agent procedure' }
    sidebar = { 'docsSidebar' => %w[expected-experience procedure] }
    _, errors, status = check(sidebar, '# Guide', files) { |root| checkout_alias(root, symlinks) }
    refute_predicate status, :success?, "core.symlinks=#{symlinks}"
    assert_includes errors, 'Docs sources cannot be symlinks: docs/procedure.md'
  end

  def git(root, *) = system('git', '-C', root, *, exception: true)

  def commit_fixture(root)
    args = %w[-c user.name=TestUser -c user.email=test@example.com -c commit.gpgsign=false]
    git(root, *args, 'commit', '--no-verify', '-qm', 'Fixture')
  end

  def checkout_alias(root, symlinks)
    path = File.join(root, 'docs/procedure.md')
    probe_symlink(path) if symlinks
    stage_alias(root)
    commit_fixture(root)
    git(root, 'config', 'core.symlinks', symlinks.to_s)
    git(root, 'checkout', '--', 'docs/procedure.md')
    assert_equal symlinks, File.symlink?(path)
  end

  def stage_alias(root)
    git(root, 'add', '.')
    object, status = Open3.capture2('git', '-C', root, 'hash-object', '-w', '--stdin',
                                    stdin_data: '../skills/shaka/references/procedure.txt')
    raise 'Could not store fixture link target' unless status.success?

    git(root, 'update-index', '--add', '--cacheinfo', "120000,#{object.strip},docs/procedure.md")
  end

  def probe_symlink(path)
    create_symlink('../skills/shaka/references/procedure.txt', path)
    File.unlink(path)
  end
end
