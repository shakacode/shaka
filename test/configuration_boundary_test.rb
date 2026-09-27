# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/configuration'

class ConfigurationBoundaryTest < Minitest::Test
  include RepositoryConfigTestHelpers

  ROOT = File.expand_path('../skills/shaka/lib/shaka', __dir__)
  INTERNAL = %w[configuration.rb repository_config.rb trusted_config_source.rb].freeze
  EXPLANATORY = %w[seam/initializer_readme.rb seam/pointer.rb].freeze
  ACCESS_CALLERS = %w[
    claim.rb doctor/checks.rb local_review/prompt_file.rb seam/initializer.rb
    seam/initializer_destination.rb seam/initializer_readme.rb seam/migration_apply.rb
    seam/migration_plan.rb seam/migrator.rb
  ].freeze

  def test_public_paths_remain_concrete_and_independent
    paths = Shaka::Configuration::Paths
    assert_equal '.agents/agent-workflow.yml', paths::CONTRACT
    assert_equal '~/.agents/trusted-github-actors.yml', paths::MACHINE_ALLOWLIST
    assert_equal '.agents/trusted-github-actors.yml', paths::REPOSITORY_ALLOWLIST
    assert_equal '.agents/bin/validate', paths::REQUIRED_COMMANDS.fetch('validate')
  end

  def test_trusted_read_never_uses_a_valid_worktree_as_fallback
    with_repository do |root|
      File.write(File.join(root, 'README.md'), "Fixture\n")
      commit_fixture(root, 'README.md')

      assert_instance_of Shaka::RepositoryConfig, Shaka::Configuration.worktree(root:)

      error = assert_raises(Shaka::Error) { Shaka::Configuration.trusted(root:, ref: 'HEAD') }

      assert_includes error.message, 'Cannot read .agents/agent-workflow.yml'
    end
  end

  def test_invalid_trusted_contract_does_not_use_valid_worktree
    with_repository do |root|
      contract = File.join(root, '.agents/agent-workflow.yml')
      valid = File.read(contract)
      File.write(contract, "review: [invalid\n")
      commit_fixture(root, '.')
      File.write(contract, valid)

      assert_instance_of Shaka::RepositoryConfig, Shaka::Configuration.worktree(root:)
      error = assert_raises(Shaka::Error) { Shaka::Configuration.trusted(root:, ref: 'HEAD') }
      assert_includes error.message, 'Invalid .agents/agent-workflow.yml'
    end
  end

  def test_production_config_access_has_one_owner
    violations = Dir.glob(File.join(ROOT, '**/*.rb')).filter_map { |file| boundary_violation(file) }

    assert_empty violations, violations.join("\n")
  end

  private

  def commit_fixture(root, path)
    system('git', '-C', root, 'init', '--quiet', exception: true)
    system('git', '-C', root, 'add', path, exception: true)
    system('git', '-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
           'commit', '--quiet', '-m', 'Trusted fixture', exception: true)
  end

  def boundary_violation(file)
    relative = file.delete_prefix("#{ROOT}/")
    return if INTERNAL.include?(relative) || relative.start_with?('configuration/', 'repository_config/')

    findings = source_findings(relative, File.read(file))
    "#{relative}: #{findings.join(', ')}" unless findings.empty?
  end

  def source_findings(relative, source)
    findings = []
    literal = source.match?(%r{["'](?:~/)?\.agents/})
    findings << 'path literal' if literal && !EXPLANATORY.include?(relative)
    findings << 'contract alias' if source.include?('RepositoryConfig::PATH')
    direct_read = /File\.(?:read|binread|write)\([^\n]*(?:CONTRACT|SEAM|POINTER_PATH)/
    findings << 'direct contract read' if source.match?(direct_read)
    direct_access = source.match?(/File\.(?:read|binread|write|open)\(/)
    findings << 'direct file access' if ACCESS_CALLERS.include?(relative) && direct_access
    findings
  end
end
