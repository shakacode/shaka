# frozen_string_literal: true

module Shaka
  # Repository-facing names belong here; packaged workflow data is separate.
  module Configuration
    # Literal names for repository and machine configuration entry points.
    module Paths
      DIRECTORY = '.agents'
      POINTER = '.agents/shaka.md'
      CONTRACT = '.agents/shaka/config.yml'
      PRIVATE_EXCLUDE_PATTERN = '/.agents/shaka/'
      COMMAND_DIRECTORY = '.agents/shaka/bin'
      REPOSITORY_ALLOWLIST = '.agents/shaka/trusted-github-actors.yml'
      MACHINE_ALLOWLIST = '~/.agents/trusted-github-actors.yml'
      MACHINE_REVIEWERS = '.agents/shaka/local-reviewers.yml' # Relative to the home directory.
      PERSONAL_SETTINGS = '.agents/shaka/config.yml' # Relative to the home directory; read only by private setup.

      REQUIRED_COMMANDS = {
        'setup' => '.agents/shaka/bin/setup',
        'validate' => '.agents/shaka/bin/validate',
        'test' => '.agents/shaka/bin/test'
      }.freeze
      OPTIONAL_COMMANDS = {
        'validate_local' => '.agents/shaka/bin/validate-local',
        'trigger_hosted_ci' => '.agents/shaka/bin/trigger-hosted-ci'
      }.freeze
      COMMANDS = REQUIRED_COMMANDS.merge(OPTIONAL_COMMANDS).freeze
      REPOSITORY_NAMES = {
        DIRECTORY: DIRECTORY, COMMAND_DIRECTORY: COMMAND_DIRECTORY, CONTRACT: CONTRACT,
        POINTER: POINTER, REPOSITORY_ALLOWLIST: REPOSITORY_ALLOWLIST
      }.freeze
      GENERATED_FILES = [CONTRACT, POINTER, *COMMANDS.values].freeze

      def self.at(root, relative) = File.join(root, relative)
    end
  end
end
