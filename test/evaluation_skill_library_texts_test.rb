# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'tmpdir'
require_relative '../eval/lib/shaka/evaluation/skill_library_texts'

class EvaluationSkillLibraryTextsTest < Minitest::Test
  TEXTS = Shaka::Evaluation::SkillLibraryTexts

  def write(root, path, text)
    FileUtils.mkdir_p(File.dirname(File.join(root, path)))
    File.write(File.join(root, path), text)
  end

  def skill(name, description, words)
    "---\nname: #{name}\ndescription: >\n  #{description}\n---\n#{'word ' * words}\n"
  end

  def named_sizes(result)
    result.values_at('median_skill', 'largest_skill').map { |use| [use['name'], use['text'].split.size] }
  end

  def library(name, **)
    Dir.mktmpdir do |root|
      yield root
      return TEXTS.library(name, root, **)
    end
  end

  def test_lists_every_skill_and_command_and_picks_the_median_and_largest_body
    result = library('addyosmani/agent-skills') do |root|
      { 'small' => 10, 'middle' => 20, 'large' => 30 }.each do |name, words|
        write(root, "skills/#{name}/SKILL.md", skill(name, "Use #{name}\n  across lines.", words))
      end
      write(root, 'commands/ship.md', "---\ndescription: Ship the change\n---\nBody\n")
    end

    assert_equal [3, 1], result.values_at('skills', 'commands')
    assert_equal "- large: Use large across lines.\n- middle: Use middle across lines.\n" \
                 "- small: Use small across lines.\n- ship: Ship the change", result['every_session']
    assert_equal [['middle', 20], ['large', 30]], named_sizes(result)
  end

  def test_reads_only_the_skills_a_plugin_manifest_installs
    result = library('mattpocock/skills') do |root|
      write(root, '.claude-plugin/plugin.json', JSON.generate('skills' => ['./skills/a/listed']))
      write(root, 'skills/a/listed/SKILL.md', skill('listed', 'Listed', 5))
      write(root, 'skills/b/personal/SKILL.md', skill('personal', 'Not installed', 5))
    end

    assert_equal '- listed: Listed', result['every_session']
  end

  def test_counts_a_skill_shared_by_two_marketplace_plugins_once
    result = library('anthropics/skills') do |root|
      plugins = [{ 'skills' => ['./skills/pdf', './skills/xlsx'] }, { 'skills' => ['./skills/pdf'] }]
      write(root, '.claude-plugin/marketplace.json', JSON.generate('plugins' => plugins))
      %w[pdf xlsx].each { |name| write(root, "skills/#{name}/SKILL.md", skill(name, name.upcase, 5)) }
    end

    assert_equal 2, result['skills']
  end

  HOOK = "escape_for_json\nsession_context=\"<WRAP>\\nIntro:\\n\\n${using_superpowers_escaped}\\n</WRAP>\"\n"

  def test_adds_the_text_the_superpowers_hook_builds_to_every_session
    result = library('obra/superpowers') do |root|
      body = "#{skill('using-superpowers', 'Start here', 3)}Keep \\1 and \\\\.\n\n"
      write(root, 'skills/using-superpowers/SKILL.md', body)
      write(root, 'hooks/session-start', HOOK)
    end

    assert_includes result['every_session'], "- using-superpowers: Start here\n\n<WRAP>\nIntro:\n\n---\n"
    assert result['every_session'].end_with?("word word word \nKeep \\1 and \\\\.\n</WRAP>")
  end

  def test_refuses_a_superpowers_hook_it_cannot_read
    [nil, HOOK.sub('Intro:', 'Say \\"hi\\":')].each do |hook|
      error = assert_raises(Shaka::Error) do
        library('obra/superpowers') do |root|
          write(root, 'skills/using-superpowers/SKILL.md', skill('u', 'U', 1))
          write(root, 'hooks/session-start', hook) if hook
        end
      end
      assert_includes error.message, 'hooks/session-start'
    end
  end

  def test_using_shaka_loads_its_skill_and_the_workflow
    result = library('shaka', shaka_workflow: 'workflow text') do |root|
      write(root, 'skills/shaka/SKILL.md', skill('shaka', 'Deliver a task', 2))
    end

    assert_equal "word word \n\n\nworkflow text", result['largest_skill']['text']
    assert_equal result['median_skill'], result['largest_skill']
  end

  def test_refuses_a_library_with_no_skills_or_unreadable_frontmatter
    assert_raises(Shaka::Error) { library('garrytan/gstack') { |_root| nil } }
    error = assert_raises(Shaka::Error) do
      library('garrytan/gstack') { |root| write(root, 'SKILL.md', "---\nname: [broken\n---\nBody\n") }
    end
    assert_includes error.message, 'SKILL.md: unreadable frontmatter'
  end
end

# Runs the real script without spending quota, so the reader, Shaka's workflow rendering, and the
# report assembly are exercised end to end.
class EvaluationSkillLibraryTokensScriptTest < Minitest::Test
  def words_only_report
    root = File.expand_path('..', __dir__)
    output, status = Open3.capture2(RbConfig.ruby, File.join(root, 'eval/bin/skill-library-tokens'),
                                    '--words-only', "shaka=#{root}")
    assert_predicate status, :success?
    JSON.parse(output)
  end

  def test_words_only_reports_sizes_without_running_a_cli
    report = words_only_report
    shaka = report['libraries'].first

    assert_nil report['clis']
    assert_equal ['shaka', 1], shaka.values_at('library', 'skills')
    assert_operator shaka['median_skill']['words'], :>, 1_000
    refute(shaka.values.grep(Hash).any? { |row| row.key?('claude') || row.key?('codex') })
  end
end
