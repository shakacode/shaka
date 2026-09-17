# frozen_string_literal: true

require_relative 'test_helper'

class SkillTest < Minitest::Test
  SKILL = File.expand_path('../skills/shaka/SKILL.md', __dir__)
  RCT_SKILL = File.expand_path('../skills/rct/SKILL.md', __dir__)
  MCT_SKILL = File.expand_path('../skills/mct-claude/SKILL.md', __dir__)
  GUIDE_LINK = %r{\]\((\.\./\.\./docs/[\w-]+\.md)(?:#([\w-]+))?\)}

  def test_public_skill_stays_within_the_context_budget
    # Issue #33 asks for a deliberate growth decision; PR #38 review set the budget by
    # content, not by cutting rules, so it is the whole procedure with room to grow.
    assert_operator File.size(SKILL), :<=, 20 * 1024
  end

  def test_shaka_skill_is_only_the_trusted_workflow_bootstrap
    skill = File.read(SKILL, encoding: 'UTF-8')

    assert_includes skill, "helper's `workflow` command"
    refute_match(/^## \d+\. /, skill)
    assert_operator skill.lines.size, :<=, 25
  end

  def test_rct_skill_stays_small
    assert_operator File.size(RCT_SKILL), :<=, 8 * 1024
  end

  def test_claude_master_tower_skill_stays_small
    assert_operator File.size(MCT_SKILL), :<=, 8 * 1024
  end

  # A skill whose frontmatter name does not match its directory is not the skill the host loads.
  def test_every_skill_declares_its_directory_name
    skills = Dir.glob(File.expand_path('../skills/*/SKILL.md', __dir__))
    refute_empty skills
    skills.each do |skill|
      declared = File.read(skill, encoding: 'UTF-8')[/^name:[ \t]*(\S+)/, 1]
      assert_equal File.basename(File.dirname(skill)), declared, skill
    end
  end

  # A moved rule must still point at a real guide section, or the agent reads nothing.
  def test_every_guide_link_resolves_to_an_existing_heading
    [SKILL, RCT_SKILL, MCT_SKILL].each do |skill|
      File.read(skill, encoding: 'UTF-8').scan(GUIDE_LINK) do |path, anchor|
        file = File.expand_path(path, File.dirname(skill))
        assert File.file?(file), "#{path} is not a guide"
        assert_includes heading_slugs(file), anchor, "#{path} has no heading for ##{anchor}" if anchor
      end
    end
  end

  def heading_slugs(file)
    File.readlines(file, encoding: 'UTF-8').grep(/\A#+ /).map do |line|
      line.sub(/\A#+ /, '').strip.downcase.gsub(/[^\w\s-]/, '').gsub(/\s+/, '-')
    end
  end
end
