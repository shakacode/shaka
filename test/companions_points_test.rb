# frozen_string_literal: true

require 'tmpdir'
require_relative 'test_helper'
require 'shaka/companions/points'

# Skill points come only from `Skill point` lines; each id must name its own file and heading.
class CompanionsPointsTest < Minitest::Test
  POINTS = Shaka::Companions::Points

  def test_packaged_procedures_declare_points_that_match_their_place
    declared = POINTS.all

    refute_empty declared
    declared.each_value do |point|
      assert_equal "#{File.basename(point.file, '.md')}##{point.heading_anchor}", point.id
    end
  end

  def test_a_moved_or_renamed_heading_fails
    procedure("# Guide\n\n## Old name\n\nSkill point: run `companions guide#new-name --root DIR`.\n") do |dir|
      error = assert_raises(Shaka::Error) { POINTS.all(dir) }

      assert_includes error.message, 'guide.md:5 names guide#new-name under #old-name'
    end
  end

  def test_a_wrapped_line_and_heading_punctuation_still_match
    text = "# Guide\n\n### Ask, then act!\n\nSkill point, when asked: run the helper's\n" \
           "`companions guide#ask-then-act --root DIR`\nand follow it.\n"
    procedure(text) { |dir| assert_equal ['guide#ask-then-act'], POINTS.all(dir).keys }
  end

  def test_a_repeated_id_fails
    line = "Skill point: run `companions guide#steps`.\n"
    procedure("# Guide\n\n## Steps\n\n#{line}\n#{line}") do |dir|
      assert_includes assert_raises(Shaka::Error) { POINTS.all(dir) }.message, 'declared more than once'
    end
  end

  def test_fenced_examples_declare_nothing
    procedure("# Guide\n\n```text\nSkill point: run `companions guide#x`.\n```\n") do |dir|
      assert_empty POINTS.all(dir)
    end
  end

  private

  def procedure(text)
    Dir.mktmpdir('points') do |dir|
      File.write(File.join(dir, 'guide.md'), text)
      yield dir
    end
  end
end
