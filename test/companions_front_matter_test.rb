# frozen_string_literal: true

require_relative 'companions_command_support'

# A broken or ambiguous SKILL.md header never lets a project skill run without asking.
class CompanionsFrontMatterTest < Minitest::Test
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

  def test_a_repeated_invocation_key_counts_as_explicit_only
    repeated = "---\ndisable-model-invocation: true\ndisable-model-invocation: false\n---\n"
    files = { '.agents/shaka/packs/team.yml' => pack('team', { 'team-check' => project(TEAM_CHECK) }),
              "#{TEAM_CHECK}/SKILL.md" => repeated }
    with_trusted_repository(extra: files) do |root, sha|
      row = run_command(root:, ref: sha).fetch('skills').first

      assert_equal ['suggest', 'it is explicit-only'], row.values_at('mode', 'basis')
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

  # The header closes on the line right after it opens; the YAML-looking body is not front matter.
  def test_an_empty_header_counts_as_explicit_only_whatever_follows
    files = { '.agents/shaka/packs/team.yml' => pack('team', { 'team-check' => project(TEAM_CHECK) }),
              "#{TEAM_CHECK}/SKILL.md" => "---\n---\nname: body\n---\n" }
    with_trusted_repository(extra: files) do |root, sha|
      row = run_command(root:, ref: sha).fetch('skills').first

      assert_equal ['suggest', 'it is explicit-only'], row.values_at('mode', 'basis')
    end
  end
end
