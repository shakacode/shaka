# frozen_string_literal: true

require_relative 'test_helper'

class SkillTest < Minitest::Test
  SKILL = File.expand_path('../skills/shaka/SKILL.md', __dir__)
  RCT_SKILL = File.expand_path('../skills/rct/SKILL.md', __dir__)
  MCT_SKILL = File.expand_path('../skills/mct-claude/SKILL.md', __dir__)
  RCT_CLAUDE_SKILL = File.expand_path('../skills/rct-claude/SKILL.md', __dir__)
  INTERNAL_GUIDE = File.expand_path('../.agents/guides/shaka-learning.md', __dir__)
  PROJECT_SKILL_ROOTS = %w[.agents .claude .codex .cursor .opencode].map do |directory|
    File.expand_path("../#{directory}/skills", __dir__)
  end.freeze
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

  # The first live trial found rules these skills lacked: exhausting the session listing,
  # and a repository check that wrongly assumed a session's origin directory is a repository.
  # Like PR #38 did for the procedure, the budget moves by content rather than by cutting
  # rules to fit a number inherited from the simpler Codex tower.
  def test_claude_tower_skills_stay_small
    [MCT_SKILL, RCT_CLAUDE_SKILL].each { |skill| assert_operator File.size(skill), :<=, 9 * 1024, skill }
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

  # A fresh Codex task discovered the candidate branch's .agents/skills copy before
  # trusted Shaka could establish the default-branch boundary. Until a trusted loader
  # exists, this repository permits no project-local skills in supported host paths;
  # introducing one requires an explicit policy and test change.
  def test_internal_learning_guide_cannot_be_loaded_as_a_candidate_skill
    assert File.file?(INTERNAL_GUIDE)
    refute(PROJECT_SKILL_ROOTS.any? { |root| File.exist?(root) || File.symlink?(root) })
  end

  # A moved rule must still point at a real guide section, or the agent reads nothing.
  def test_every_guide_link_resolves_to_an_existing_heading
    [SKILL, RCT_SKILL, MCT_SKILL, RCT_CLAUDE_SKILL, INTERNAL_GUIDE].each do |skill|
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
