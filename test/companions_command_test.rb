# frozen_string_literal: true

require_relative 'companions_command_support'

# `shaka companions` reads repository packs and project skills only at the trusted commit.
class CompanionsCommandTest < Minitest::Test
  include CompanionsCommandSupport

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

  def test_a_repository_without_team_settings_reports_why_instead_of_failing
    Dir.mktmpdir('no-settings') do |root|
      write(root, 'README.md', "Plain repository\n")
      %w[init add commit].each { |step| git_step(root, step) }
      result = run_command(root:, ref: 'HEAD')

      assert_empty result['skills']
      assert_includes result['repository_packs'], 'no usable team settings'
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

  def test_the_command_prints_every_point_as_json_and_refuses_a_missing_point
    with_trusted_repository do |root, sha|
      output, = capture_io { assert_equal 0, run_cli('--all', '--root', root, '--ref', sha) }
      _, error = capture_io { assert_equal 1, run_cli('--root', root) }
      json = JSON.parse(output)

      assert_equal [sha, %w[team-check]], [json['settings_ref'], json['skills'].map { |row| row['skill'] }]
      assert_includes error, 'Usage: shaka companions POINT|--all'
    end
  end

  private

  def git_step(root, step)
    arguments = { 'init' => %w[init --quiet], 'add' => %w[add .],
                  'commit' => %w[-c user.name=T -c user.email=t@example.com commit --quiet -m Plain] }
    git(root, *arguments.fetch(step))
  end

  def run_cli(*arguments) = Shaka::Companions::Command.run(arguments)
end
