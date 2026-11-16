# frozen_string_literal: true

require_relative 'companions_command_support'

# Each installed or linked copy of a skill keeps the limits its own files and links imply.
class CompanionsInstalledCopiesTest < Minitest::Test
  include CompanionsCommandSupport

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

  def test_an_unterminated_front_matter_header_counts_as_explicit_only
    broken = "---\nname: team-check\ndisable-model-invocation: true\n"
    files = { '.agents/shaka/packs/team.yml' => pack('team', { 'team-check' => project(TEAM_CHECK) }),
              "#{TEAM_CHECK}/SKILL.md" => broken }
    with_trusted_repository(extra: files) do |root, sha|
      row = run_command(root:, ref: sha).fetch('skills').first

      assert_equal ['suggest', 'it is explicit-only'], row.values_at('mode', 'basis')
    end
  end

  def test_a_linked_alias_shares_the_limits_of_the_skill_it_points_to
    with_trusted_repository(extra: aliased_team) do |root, sha|
      rows = run_command(root:, ref: sha).fetch('skills')

      assert_equal([%w[team-check suggest]], rows.map { |row| row.values_at('skill', 'mode') })
    end
  end

  def test_each_installed_copy_keeps_its_own_front_matter
    write(@home, '.claude/skills/coverage/SKILL.md', "---\nname: coverage\ndisable-model-invocation: true\n---\n")
    write(@home, '.agents/skills/coverage/SKILL.md', "---\nname: coverage\n---\n")
    third_party = { 'coverage' => { 'points' => { POINT => mode('use') } } }
    team = pack('team', third_party, source: 'https://github.com/example/perf', match: { 'paths' => ['*/coverage'] })
    with_trusted_repository(extra: { '.agents/shaka/packs/team.yml' => team }) do |root, sha|
      rows = run_command(root:, ref: sha).fetch('skills')

      assert_equal [['~/.agents/skills/coverage', 'use'], ['~/.claude/skills/coverage', 'suggest']],
                   rows.map { |row| row.values_at('location', 'mode') }.sort
    end
  end
end
