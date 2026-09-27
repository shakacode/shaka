# frozen_string_literal: true

require_relative '../configuration/paths'

module Shaka
  class RepositoryConfig
    # The portable command interface has fixed names; repositories adapt behind these paths.
    module CommandPaths
      REQUIRED = Configuration::Paths::REQUIRED_COMMANDS
      OPTIONAL = Configuration::Paths::OPTIONAL_COMMANDS
      LEGACY_OPTIONAL = Configuration::Paths::LEGACY_OPTIONAL_COMMANDS
      ALL = Configuration::Paths::COMMANDS
    end
  end
end
