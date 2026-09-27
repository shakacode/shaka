# frozen_string_literal: true

module Shaka
  # Repository-facing names belong here; packaged workflow data is separate.
  module Configuration
    # Literal names for repository and machine configuration entry points.
    module Paths
      DIRECTORY = '.agents'
      COMMAND_DIRECTORY = '.agents/bin'
      CONTRACT = '.agents/agent-workflow.yml'
      POINTER = '.agents/shaka.md'
      LEGACY_README = '.agents/README.md'
      REPOSITORY_ALLOWLIST = '.agents/trusted-github-actors.yml'
      MACHINE_ALLOWLIST = '~/.agents/trusted-github-actors.yml'

      REQUIRED_COMMANDS = {
        'setup' => '.agents/bin/setup',
        'validate' => '.agents/bin/validate',
        'test' => '.agents/bin/test'
      }.freeze
      OPTIONAL_COMMANDS = {
        'validate_local' => '.agents/bin/validate-local',
        'trigger_hosted_ci' => '.agents/bin/trigger-hosted-ci'
      }.freeze
      LEGACY_OPTIONAL_COMMANDS = {
        'validate_local' => '.agents/bin/validate_local',
        'trigger_hosted_ci' => '.agents/bin/trigger_hosted_ci'
      }.freeze
      COMMANDS = REQUIRED_COMMANDS.merge(OPTIONAL_COMMANDS).freeze

      def self.at(root, relative) = File.join(root, relative)
    end
  end
end
