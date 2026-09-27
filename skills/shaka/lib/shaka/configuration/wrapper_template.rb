# frozen_string_literal: true

module Shaka
  module Configuration
    # Git-based root lookup shared by layout upgrades and new wrapper generation.
    module WrapperTemplate
      SHELL_ROOT = 'root=$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)'
    end
  end
end
