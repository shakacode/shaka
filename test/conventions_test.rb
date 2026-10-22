# frozen_string_literal: true

require_relative 'seam_initializer_layout_test'
require 'shaka/conventions'
require 'shaka/configuration/fingerprint'

class ConventionsTest < Minitest::Test
  def test_listed_file_resolves_beside_the_configuration
    assert_equal '.agents/shaka/reviewers/checkpoint.md', Shaka::Conventions.path('reviewers/checkpoint.md')
    assert_raises(Shaka::Error) { Shaka::Conventions.path('reviewers/checkpont.md') }
  end

  def test_readme_table_names_reader_and_absent_behavior_between_markers
    readme = Shaka::Conventions.readme('reviewers')
    table = readme[readme.index(Shaka::Conventions::TABLE_BEGIN)..readme.index(Shaka::Conventions::TABLE_END)]

    assert_includes table, '| `checkpoint.md` | Checkpoint reviewer |'
    assert_includes table, 'an empty file counts as absent'
  end

  def test_rejects_an_entry_missing_a_field
    source = { 'reviewers' => { 'introduction' => 'Text', 'files' => { 'checkpoint.md' => { 'reader' => 'x' } } } }
    error = assert_raises(Shaka::Error) { Shaka::Conventions.load(YAML.dump(source)) }

    assert_includes error.message, 'reviewers/checkpoint.md needs reader'
  end
end

class ConventionsSeamInitTest < Minitest::Test
  include SeamInitializerTestHelpers
  include SeamInitializerLayoutHelpers

  def test_init_writes_the_reviewers_readme_and_points_the_header_at_it
    with_repository do |root|
      _, error, status = init(root)

      assert_predicate status, :success?, error
      assert_equal Shaka::Conventions.readme('reviewers'),
                   File.read(File.join(root, '.agents/shaka/reviewers/README.md'))
      assert_includes File.read(File.join(root, '.agents/shaka/config.yml')), '# reviewers/README.md lists each file'
    end
  end

  def test_init_keeps_a_maintainer_readme
    with_repository do |root|
      FileUtils.mkdir_p(File.join(root, '.agents/shaka/reviewers'))
      File.write(File.join(root, '.agents/shaka/reviewers/README.md'), "Our notes\n")
      _, error, status = init(root)

      assert_predicate status, :success?, error
      assert_equal "Our notes\n", File.read(File.join(root, '.agents/shaka/reviewers/README.md'))
    end
  end
end

class ConventionsFingerprintTest < Minitest::Test
  RULES = '.agents/shaka/reviewers/checkpoint.md'

  def setup
    @root = Dir.mktmpdir('fingerprint-conventions')
    FileUtils.mkdir_p(File.join(@root, '.agents/bin'))
    File.write(File.join(@root, '.agents/bin/test'), 'test')
    File.write(File.join(@root, '.agents/agent-workflow.yml'), 'config')
    system('git', '-C', @root, 'init', '--quiet', exception: true)
  end

  def teardown = FileUtils.remove_entry(@root)

  def test_committed_rules_change_the_file_component
    absent = files(commit)
    FileUtils.mkdir_p(File.join(@root, File.dirname(RULES)))
    File.write(File.join(@root, RULES), 'one')
    first = files(commit)
    File.write(File.join(@root, RULES), 'two')

    refute_equal absent, first
    refute_equal first, files(commit)
  end

  private

  def commit
    system('git', '-C', @root, 'add', '.', exception: true)
    system('git', '-C', @root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
           'commit', '--quiet', '--allow-empty', '-m', 'change', exception: true)
    Open3.capture2('git', '-C', @root, 'rev-parse', 'HEAD').first.strip
  end

  def files(ref)
    settings = { 'commands' => { 'test' => '.agents/bin/test' }, 'review' => {}, 'opening_check' => {},
                 'paths' => { 'policy_configuration' => '.agents/agent-workflow.yml' } }
    installation = { 'schema_version' => 1, 'version' => '1', 'source' => { 'kind' => 'uninstalled' } }
    Shaka::Configuration::Fingerprint.build(root: @root, effective_settings: settings, repository: 'shakacode/shaka',
                                            installation:, trusted_ref: ref).components.fetch('files')
  end
end
