# frozen_string_literal: true

module Shaka
  module Configuration
    # Git root lookup used by layout upgrades; seam init adopts it in #276.
    module WrapperTemplate
      SHELL_ROOT = 'root=$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)'
    end
  end
end
