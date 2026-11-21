# frozen_string_literal: true

module Shaka
  # Restricts tools that would otherwise remain available even with the shell disabled.
  module CodexExec
    TOOL_RESTRICTIONS = %w[--disable apps --disable view_image -c web_search="disabled"].freeze
  end
end
