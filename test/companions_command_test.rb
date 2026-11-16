# frozen_string_literal: true

require 'tmpdir'
require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/companions/command'

# `shaka companions` reads repository packs and project skills only at the trusted commit.
class CompanionsCommandTest < Minitest::Test
  include RepositoryConfigTestHelpers

  POINT = 'ui-verification#ui-changes'
  TEAM_CHECK = '.agents/skills/team-check'
  SKILL = "---\nname: a-skill\n---\n"

  def setup
    @home = Dir.mktmpdir('companions-home')
  end

  def teardown = FileUtils.remove_entry(@home)

  def test_repository_packs_come_from_the_trusted_commit_only
    with_trusted_repository(extra: two_skill_team) do |root, sha|
      add_candidate_changes(root)
      rows = run_command(root:, ref: sha).fetch('skills')

      assert_equal([%w[team team-check use], %w[team new-check decline]],
                   rows.map { |row| row.values_at('pack', 'skill', 'mode') })
      assert_includes rows.last['basis'], 'candidate branch'
      assert_equal sha, rows.first['revision']
    end
  end

  def test_without_a_ref_no_repository_pack_applies
    with_trusted_repository do |root, _sha|
      result = run_command(root:, ref: nil)

      assert_empty result.fetch('skills')
      assert_equal 'not read: no --ref', result.fetch('repository_packs')
    end
  end

  def test_a_settings_preview_reads_no_repository_pack
    with_trusted_repository do |root, sha|
      Shaka::Configuration::SettingsPreview.new(root:).start(sha)
      result = run_command(root:, ref: sha)

      assert_empty result.fetch('skills')
      assert_equal 'not read: settings source is preview/local', result.fetch('repository_packs')
    end
  end

  def test_a_personal_pack_finds_its_own_copy_among_same_named_skills
    write(@home, '.claude/skills/coverage/SKILL.md', "---\nname: coverage\ndisable-model-invocation: true\n---\n")
    write(@home, '.agents/skills/coverage/SKILL.md', "---\nname: coverage\n---\n")
    write(@home, '.agents/shaka/packs/mine.yml',
          pack('mine', { 'coverage' => { 'points' => { POINT => mode('suggest') } } },
               source: 'https://github.com/example/perf', match: { 'paths' => ['*/.claude/skills/*'] }))
    with_trusted_repository do |root, sha|
      row = run_command(root:, ref: sha).fetch('skills').first

      assert_equal [true, '~/.claude/skills/coverage', 'suggest'], row.values_at('installed', 'location', 'mode')
    end
  end

  def test_an_unknown_point_is_refused
    with_trusted_repository do |root, sha|
      error = assert_raises(Shaka::Error) { run_command(root:, ref: sha, point: 'delivery#nowhere') }

      assert_includes error.message, 'Unknown skill point delivery#nowhere'
    end
  end

  def test_a_repository_pack_naming_an_unknown_point_warns
    stale = { '.agents/shaka/packs/team.yml' => pack('team', { 'x' => project('a', 'old#gone') }) }
    with_trusted_repository(extra: stale) do |root, sha|
      assert_includes run_command(root:, ref: sha).fetch('warnings').first, 'unknown skill point old#gone ignored'
    end
  end

  private

  def run_command(root:, ref:, point: POINT)
    Shaka::Companions::Command.new(point:, root:, ref:, home: @home).call
  end

  # A repository whose trusted commit holds one pack with one project skill.
  def with_trusted_repository(extra: nil)
    with_repository do |root|
      files = extra || { '.agents/shaka/packs/team.yml' => pack('team', { 'team-check' => project(TEAM_CHECK) }),
                         "#{TEAM_CHECK}/SKILL.md" => SKILL }
      files.each { |path, text| write(root, path, text) }
      git(root, 'init', '--quiet')
      git(root, 'add', '.')
      git(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '--quiet', '-m', 'Trusted')
      yield root, git(root, 'rev-parse', 'HEAD').strip
    end
  end

  def git(root, *)
    output, status = Open3.capture2('git', '-C', root, *)
    assert_predicate status, :success?
    output
  end

  def write(base, relative, text)
    path = File.join(base, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, text)
  end

  # A new pack, and the second project skill's directory, exist only on the candidate branch.
  def add_candidate_changes(root)
    write(root, '.agents/shaka/packs/candidate.yml', pack('candidate', { 'other' => project('.agents/skills/x') }))
    write(root, '.agents/skills/new-check/SKILL.md', SKILL)
  end

  # The trusted commit's pack names two project skills; only the first exists there.
  def two_skill_team
    team = pack('team', { 'team-check' => project(TEAM_CHECK), 'new-check' => project('.agents/skills/new-check') })
    { '.agents/shaka/packs/team.yml' => team, "#{TEAM_CHECK}/SKILL.md" => SKILL }
  end

  def mode(value) = { 'mode' => value, 'reason' => 'Fits this step' }

  def project(path, point = POINT) = { 'path' => path, 'points' => { point => mode('use') } }

  def pack(name, skills, **top)
    YAML.dump({ 'version' => 1, 'pack' => name, **top.transform_keys(&:to_s), 'skills' => skills })
  end
end
