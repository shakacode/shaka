# frozen_string_literal: true

require_relative 'companions_command_support'

# A project skill's limits come from its files and links at the trusted commit.
class CompanionsProjectSkillsTest < Minitest::Test
  include CompanionsCommandSupport

  def test_an_unterminated_front_matter_header_counts_as_explicit_only
    broken = "---\nname: team-check\ndisable-model-invocation: true\n"
    files = { '.agents/shaka/packs/team.yml' => pack('team', { 'team-check' => project(TEAM_CHECK) }),
              "#{TEAM_CHECK}/SKILL.md" => broken }
    with_trusted_repository(extra: files) do |root, sha|
      row = run_command(root:, ref: sha).fetch('skills').first

      assert_equal ['suggest', 'it is explicit-only'], row.values_at('mode', 'basis')
    end
  end

  def test_an_unreadable_skill_file_counts_as_explicit_only
    files = { '.agents/shaka/packs/team.yml' => pack('team', { 'team-check' => project(TEAM_CHECK) }),
              "#{TEAM_CHECK}/SKILL.md" => '' }
    with_trusted_repository(extra: files) do |root, sha|
      result = run_command(root:, ref: sha)

      assert_equal([['suggest', 'it is explicit-only']], result['skills'].map { |row| row.values_at('mode', 'basis') })
      refute_empty result['warnings']
    end
  end

  def test_a_linked_alias_shares_the_limits_of_the_skill_it_points_to
    with_trusted_repository(extra: aliased_team) do |root, sha|
      rows = run_command(root:, ref: sha).fetch('skills')

      assert_equal([['alias', 'suggest', 'it fans out workers']], rows.map do |row|
        row.values_at('skill', 'mode', 'basis')
      end)
    end
  end

  # Two skills whose SKILL.md files link to one shared file are still two skills.
  def test_a_linked_skill_file_keeps_the_skill_directory_as_identity
    shared = [:link, '../../../shared/common.md']
    fans_out = project(TEAM_CHECK).merge('fans_out' => true)
    team = pack('team', { 'team-check' => fans_out, 'other' => project('.agents/skills/other') })
    files = { '.agents/shaka/packs/team.yml' => team, 'shared/common.md' => SKILL,
              "#{TEAM_CHECK}/SKILL.md" => shared, '.agents/skills/other/SKILL.md' => shared }
    with_trusted_repository(extra: files) do |root, sha|
      rows = run_command(root:, ref: sha).fetch('skills')

      assert_equal([%w[team-check suggest], %w[other use]], rows.map { |row| row.values_at('skill', 'mode') })
    end
  end

  # The candidate turns `team-check` into a link to `other`, which fans out; the trusted tree keeps them apart.
  def test_a_link_added_on_the_candidate_branch_does_not_change_identity
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

      assert_equal([['suggest', 'it is not installed']], result['skills'].map { |row| row.values_at('mode', 'basis') })
      refute_empty result['warnings']
    end
  end

  def test_a_bare_header_marker_counts_as_explicit_only
    files = { '.agents/shaka/packs/team.yml' => pack('team', { 'team-check' => project(TEAM_CHECK) }),
              "#{TEAM_CHECK}/SKILL.md" => '---' }
    with_trusted_repository(extra: files) do |root, sha|
      row = run_command(root:, ref: sha).fetch('skills').first

      assert_equal ['suggest', 'it is explicit-only'], row.values_at('mode', 'basis')
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

      assert_equal(['team-check'], run_command(root:, ref: 'HEAD')['skills'].map { |row| row['skill'] })
    end
  end
end
