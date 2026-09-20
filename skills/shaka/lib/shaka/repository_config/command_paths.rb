# frozen_string_literal: true

module Shaka
  class RepositoryConfig
    # The portable command interface has fixed names; repositories adapt behind these paths.
    module CommandPaths
      REQUIRED = {
        'setup' => '.agents/bin/setup',
        'validate' => '.agents/bin/validate',
        'test' => '.agents/bin/test'
      }.freeze
      OPTIONAL = {
        'validate_local' => '.agents/bin/validate-local',
        'trigger_hosted_ci' => '.agents/bin/trigger-hosted-ci'
      }.freeze
      LEGACY_OPTIONAL = {
        'validate_local' => '.agents/bin/validate_local',
        'trigger_hosted_ci' => '.agents/bin/trigger_hosted_ci'
      }.freeze
      ALL = REQUIRED.merge(OPTIONAL).freeze
    end
  end
end
