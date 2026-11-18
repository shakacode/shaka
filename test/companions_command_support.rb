# frozen_string_literal: true

require 'tmpdir'
require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/companions/command'

# A trusted repository for `shaka companions` tests.
module CompanionsCommandSupport
  include RepositoryConfigTestHelpers

  POINT = 'ui-verification#ui-changes'
  TEAM_CHECK = '.agents/skills/team-check'
  SKILL = "---\nname: a-skill\n---\n"

  private

  def run_command(root:, ref:, point: POINT)
    Shaka::Companions::Command.new(point:, root:, ref:).call
  end

  # A repository whose trusted commit holds one pack with one project skill.
  def with_trusted_repository(extra: nil)
    with_repository do |root|
      files = extra || { '.agents/shaka/packs/team.yml' => pack('team', { 'team-check' => project(TEAM_CHECK) }),
                         "#{TEAM_CHECK}/SKILL.md" => SKILL }
      files.each { |path, text| add_file(root, path, text) }
      git(root, 'init', '--quiet')
      git(root, 'add', '.')
      git(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '--quiet', '-m', 'Trusted')
      yield root, git(root, 'rev-parse', 'HEAD').strip
    end
  end

  def git(root, *)
    output, status = Open3.capture2('git', '-C', root, *)
    assert_predicate status, :success?
    output
  end

  def write(base, relative, text)
    path = File.join(base, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, text)
  end

  # A new pack, and the second project skill's directory, exist only on the candidate branch.
  def add_candidate_changes(root)
    write(root, '.agents/shaka/packs/candidate.yml', pack('candidate', { 'other' => project('.agents/skills/x') }))
    write(root, '.agents/skills/new-check/SKILL.md', SKILL)
  end

  # `alias` links to `team-check`, which fans out at another point; the alias alone claims `use` here.
  def aliased_team
    fans_out = project(TEAM_CHECK).merge('fans_out' => true,
                                         'points' => { 'delivery#agree-on-the-design-first' => mode('suggest') })
    team = pack('team', { 'team-check' => fans_out, 'alias' => project('.agents/skills/alias') })
    { '.agents/shaka/packs/team.yml' => team, "#{TEAM_CHECK}/SKILL.md" => SKILL,
      '.agents/skills/alias' => [:link, 'team-check'] }
  end

  # The trusted commit's pack names two project skills; only the first exists there.
  def two_skill_team
    team = pack('team', { 'team-check' => project(TEAM_CHECK), 'new-check' => project('.agents/skills/new-check') })
    { '.agents/shaka/packs/team.yml' => team, "#{TEAM_CHECK}/SKILL.md" => SKILL }
  end

  def mode(value) = { 'mode' => value, 'reason' => 'Fits this step' }

  def project(path, point = POINT) = { 'path' => path, 'points' => { point => mode('use') } }

  def pack(name, skills) = YAML.dump({ 'version' => 1, 'pack' => name, 'skills' => skills })

  # A [:link, TARGET] value makes a symbolic link instead of a file.
  def add_file(root, path, text)
    return write(root, path, text) unless text.is_a?(Array)

    FileUtils.mkdir_p(File.dirname(File.join(root, path)))
    File.symlink(text.last, File.join(root, path))
  end
end
