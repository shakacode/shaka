# frozen_string_literal: true

require 'tmpdir'
require_relative 'test_helper'
require_relative 'doctor_companion_skills_support'
require 'shaka/companions/inventory'

# Packaged packs must name known points, and a plugin's copy is recognized by its plugin name.
class CompanionsInventoryTest < Minitest::Test
  include CompanionSkillsSupport

  POINT = 'ui-verification#ui-changes'
  SUGGEST = { 'mode' => 'suggest', 'reason' => 'Fits' }.freeze

  def test_a_packaged_pack_naming_an_unknown_point_is_refused
    Dir.mktmpdir('packaged') do |packaged|
      File.write(File.join(packaged, 'perf.yml'), pack('old#gone'))

      error = assert_raises(Shaka::Error) { inventory(packaged:).entries }

      assert_includes error.message, 'unknown skill point old#gone'
    end
  end

  def test_a_plugin_copy_matches_by_its_plugin_name
    plugin('perf', skills: ['coverage'])
    write('.agents/shaka/packs/perf.yml', pack(POINT))

    entry = inventory.entries.first

    assert_equal [true, '~/.claude/plugins/cache/market/perf/skills/coverage'], [entry.installed, entry.location]
  end

  private

  def inventory(packaged: File.join(@home, 'none'))
    Shaka::Companions::Inventory.new(home: @home, root: @home, sha: nil, points: [POINT], packaged:)
  end

  def pack(point)
    YAML.dump({ 'version' => 1, 'pack' => 'perf', 'source' => 'https://github.com/example/perf',
                'match' => { 'plugins' => ['perf'] },
                'skills' => { 'coverage' => { 'points' => { point => SUGGEST } } } })
  end
end
