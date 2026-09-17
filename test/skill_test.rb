# frozen_string_literal: true

require_relative 'test_helper'

class SkillTest < Minitest::Test
  SKILL = File.expand_path('../skills/shaka/SKILL.md', __dir__)
  RCT_SKILL = File.expand_path('../skills/rct/SKILL.md', __dir__)
  GUIDE_LINK = %r{\]\((\.\./\.\./docs/[\w-]+\.md)(?:#([\w-]+))?\)}

  def test_public_skill_stays_within_the_context_budget
    # Issue #33 asks for a deliberate growth decision; PR #38 review set the budget by
    # content, not by cutting rules, so it is the whole procedure with room to grow.
    assert_operator File.size(SKILL), :<=, 20 * 1024
  end

  def test_rct_skill_stays_small
    assert_operator File.size(RCT_SKILL), :<=, 8 * 1024
  end

  # A moved rule must still point at a real guide section, or the agent reads nothing.
  def test_every_guide_link_resolves_to_an_existing_heading
    [SKILL, RCT_SKILL].each do |skill|
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
