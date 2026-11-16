# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/companions/pack'

# The pack file schema refuses entries the resolver could not apply safely.
class CompanionsPackTest < Minitest::Test
  POINT = 'ui-verification#ui-changes'

  def test_a_valid_pack_records_only_stated_flags
    skill = parse(skills: { 'coverage' => { 'setup' => true,
                                            'points' => { POINT => use_or('suggest') } } }).skills.first

    assert_equal({ 'setup' => true }, skill.flags)
    assert_equal ['suggest', 'Checks coverage'], skill.points.fetch(POINT)
  end

  def test_a_packaged_use_needs_a_study
    assert_refused('packaged use entry without a study', skills: { 'coverage' => { 'points' => { POINT => use_or } } })
    assert parse(skills: { 'coverage' => { 'study' => 'https://example.com/study', 'points' => { POINT => use_or } } })
  end

  def test_a_personal_or_repository_use_needs_no_study
    %w[personal repository].each do |layer|
      assert parse({ skills: { 'coverage' => { 'points' => { POINT => use_or } } } }, layer:)
    end
  end

  def test_a_pack_wide_setting_may_only_decline
    assert_refused('may only decline', skills: { 'coverage' => { 'points' => { '*' => use_or('suggest') } } })
  end

  def test_only_a_repository_pack_names_a_project_skill
    project = { skills: { 'local' => { 'path' => '.agents/skills/local', 'points' => {} } } }

    assert_refused('allowed only in a repository pack', project)
    assert parse(project.merge(source: nil, match: {}), layer: 'repository')
    assert_refused('relative directory', { skills: { 'local' => { 'path' => '../x' } } }, layer: 'repository')
  end

  def test_a_third_party_skill_needs_a_way_to_recognize_its_copy
    assert_refused('needs match.plugins or match.paths', match: {}, skills: { 'coverage' => {} })
  end

  def test_unknown_keys_and_bad_values_are_refused
    assert_refused('unknown key colour', colour: 'red')
    assert_refused('must be true or false', skills: { 'coverage' => { 'fans_out' => 'yes' } })
    assert_refused('must set mode and reason',
                   skills: { 'coverage' => { 'points' => { POINT => { 'mode' => 'use' } } } })
    assert_refused('not valid YAML', text: "skills: [\n")
  end

  private

  def use_or(mode = 'use') = { 'mode' => mode, 'reason' => 'Checks coverage' }

  def parse(overrides = {}, layer: 'packaged', **more)
    overrides = overrides.merge(more)
    data = { 'version' => 1, 'pack' => 'perf', 'source' => 'https://github.com/example/perf',
             'match' => { 'plugins' => ['perf'] } }
    overrides.each { |key, value| value.nil? ? data.delete(key.to_s) : data[key.to_s] = value }
    text = overrides.fetch(:text, YAML.dump(data))
    Shaka::Companions::Pack.parse(text, layer:, label: 'perf.yml')
  end

  def assert_refused(message, overrides = {}, layer: 'packaged', **more)
    overrides = overrides.merge(more)
    error = assert_raises(Shaka::Error) { parse(overrides, layer:) }
    assert_includes error.message, message
  end
end
