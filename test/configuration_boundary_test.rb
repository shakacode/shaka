# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/configuration'

class ConfigurationBoundaryTest < Minitest::Test
  include RepositoryConfigTestHelpers

  ROOT = File.expand_path('../skills/shaka/lib/shaka', __dir__)
  INTERNAL = %w[configuration.rb repository_config.rb trusted_config_source.rb].freeze
  EXPLANATORY = %w[seam/initializer_readme.rb seam/pointer.rb].freeze

  def test_public_paths_remain_concrete_and_independent
    paths = Shaka::Configuration::Paths
    assert_equal '.agents/agent-workflow.yml', paths::CONTRACT
    assert_equal '~/.agents/trusted-github-actors.yml', paths::MACHINE_ALLOWLIST
    assert_equal '.agents/trusted-github-actors.yml', paths::REPOSITORY_ALLOWLIST
    assert_equal '.agents/bin/validate', paths::REQUIRED_COMMANDS.fetch('validate')
  end

  def test_trusted_read_never_uses_a_valid_worktree_as_fallback
    with_repository do |root|
      assert_instance_of Shaka::RepositoryConfig, Shaka::Configuration.worktree(root:)

      error = assert_raises(Shaka::Error) { Shaka::Configuration.trusted(root:, ref: 'missing-ref') }

      assert_includes error.message, 'Invalid trusted ref'
    end
  end

  def test_production_config_access_has_one_owner
    violations = Dir.glob(File.join(ROOT, '**/*.rb')).filter_map { |file| boundary_violation(file) }

    assert_empty violations, violations.join("\n")
  end

  private

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
    findings
  end
end
