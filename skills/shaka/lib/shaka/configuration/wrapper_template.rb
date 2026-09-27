# frozen_string_literal: true

module Shaka
  module Configuration
    # Git root lookup used by layout upgrades; seam init adopts it in #276.
    module WrapperTemplate
      SHELL_ROOT = 'root=$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR -u GIT_PREFIX ' \
                   '-u GIT_CEILING_DIRECTORIES ' \
                   'git -C "$(dirname -- "$0")" rev-parse --show-toplevel) || exit $?'
    end
  end
end
