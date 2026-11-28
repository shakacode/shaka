# frozen_string_literal: true

require_relative 'publication_test'

# Issue #1027: a pack names the upstream skill collection, so renamed ports and copies count together.
class PublicationSkillsPackTest < Minitest::Test
  def render(records)
    Shaka::Publication.description(PublicationRegressionTest.new(:unused).description_content('skills_used' => records))
  end

  def skill(**changes)
    { 'name' => 'pstack-investigate', 'source' => 'PStack', 'revision' => 'UNKNOWN',
      'phase' => 'implementation', 'contribution' => 'Investigated the failing parser',
      'evidence' => 'agent-reported', 'corroboration' => nil }.merge(changes)
  end

  def test_pack_names_the_upstream_pack_so_renamed_ports_count_together
    tdd = skill('name' => 'pstack-tdd', 'source' => 'justin808/plugins', 'pack' => 'cursor/plugins/pstack')
    rendered = render([tdd, skill('name' => 'to-spec', 'source' => 'AI Hero')])

    assert_includes rendered, '| Skill | Pack | Source | Revision |'
    assert_includes rendered, '| pstack-tdd | `cursor/plugins/pstack` | justin808/plugins | UNKNOWN |'
    assert_includes rendered, '| to-spec | — | AI Hero | UNKNOWN |'
  end

  def test_reports_without_a_pack_render_as_before
    rendered = render([skill])

    assert_includes rendered, '| Skill | Source | Revision |'
    assert_includes rendered, '| pstack-investigate | PStack | UNKNOWN |'
  end

  def test_pack_renders_literally_so_markdown_cannot_change_the_key
    assert_includes render([skill('pack' => 'owner/repo/_core_/skills')]), '| `owner/repo/_core_/skills` |'
  end

  def test_a_repository_root_or_a_dot_directory_can_be_a_pack
    ['cursor/plugins', 'owner/repo/.agents/shaka/packs/team.yml'].each do |pack|
      assert_includes render([skill('pack' => pack)]), "| `#{pack}` |"
    end
  end

  def test_pack_must_be_a_repository_and_optional_path
    ['pstack', 'cursor/plugins pstack', 'cursor/../pstack', 'cursor/plugins/.', 'https://github.com/cursor/plugins',
     '', nil, 'cursor//pstack', '/cursor/plugins', 'cursor/plugins`x', ['cursor/plugins']].each do |pack|
      error = assert_raises(Shaka::Error) { render([skill('pack' => pack)]) }
      assert_includes error.message, 'pack'
    end
  end
end
