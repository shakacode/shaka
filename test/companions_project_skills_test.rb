# frozen_string_literal: true

require_relative 'companions_command_support'

# A project skill's limits come from its files and links at the trusted commit.
class CompanionsProjectSkillsTest < Minitest::Test
  include CompanionsCommandSupport

  def test_a_skill_directory_reached_through_a_link_is_declined
    with_trusted_repository(extra: aliased_team) do |root, sha|
      result = run_command(root:, ref: sha)

      assert_equal([['alias', 'decline', nil]], result['skills'].map do |row|
        row.values_at('skill', 'mode', 'location')
      end)
      assert(result['warnings'].any? { |warning| warning.include?('linked skill paths are not supported') })
    end
  end

  def test_a_linked_skill_file_is_declined
    files = { '.agents/shaka/packs/team.yml' => pack('team', { 'team-check' => project(TEAM_CHECK) }),
              'shared/common.md' => SKILL, "#{TEAM_CHECK}/SKILL.md" => [:link, '../../../shared/common.md'] }
    with_trusted_repository(extra: files) do |root, sha|
      rows = run_command(root:, ref: sha).fetch('skills')

      assert_equal([['decline', 'it is not at the trusted commit']], rows.map { |row| row.values_at('mode', 'basis') })
    end
  end

  # The candidate turns `team-check` into a link to `other`, which fans out; only trusted files count.
  def test_a_link_added_on_the_candidate_branch_changes_nothing
    fans_out = project('.agents/skills/other').merge('fans_out' => true)
    team = pack('team', { 'team-check' => project(TEAM_CHECK), 'other' => fans_out })
    files = { '.agents/shaka/packs/team.yml' => team, "#{TEAM_CHECK}/SKILL.md" => SKILL,
              '.agents/skills/other/SKILL.md' => SKILL }
    with_trusted_repository(extra: files) do |root, sha|
      FileUtils.rm_r(File.join(root, TEAM_CHECK))
      File.symlink('other', File.join(root, TEAM_CHECK))
      rows = run_command(root:, ref: sha).fetch('skills')

      assert_equal([%w[team-check use], %w[other suggest]], rows.map { |row| row.values_at('skill', 'mode') })
    end
  end

  def test_a_trusted_link_leaving_the_repository_is_a_warning_not_a_failure
    files = { '.agents/shaka/packs/team.yml' => pack('team', { 'team-check' => project(TEAM_CHECK) }),
              "#{TEAM_CHECK}/SKILL.md" => [:link, '../../../../outside.md'] }
    with_trusted_repository(extra: files) do |root, sha|
      result = run_command(root:, ref: sha)

      assert_equal([['decline', 'it is not at the trusted commit']], result['skills'].map do |row|
        row.values_at('mode', 'basis')
      end)
      refute_empty result['warnings']
    end
  end

  # The trusted SKILL.md is a link to nothing; the candidate branch adds the file it points to.
  def test_a_dangling_trusted_link_completed_on_the_candidate_branch_is_declined
    files = { '.agents/shaka/packs/team.yml' => pack('team', { 'team-check' => project(TEAM_CHECK) }),
              "#{TEAM_CHECK}/SKILL.md" => [:link, 'real.md'] }
    with_trusted_repository(extra: files) do |root, sha|
      write(root, "#{TEAM_CHECK}/real.md", SKILL)
      row = run_command(root:, ref: sha).fetch('skills').first

      assert_equal ['decline', nil], row.values_at('mode', 'location')
    end
  end

  def test_an_executable_pack_file_is_still_read
    with_trusted_repository do |root, _sha|
      File.chmod(0o755, File.join(root, '.agents/shaka/packs/team.yml'))
      git(root, 'add', '.')
      git(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '--quiet', '-m', 'Mode')
      assert git(root, 'ls-files', '-s', '.agents/shaka/packs/team.yml').start_with?('100755')

      assert_equal(['team-check'], run_command(root:, ref: 'HEAD')['skills'].map { |row| row['skill'] })
    end
  end
end
