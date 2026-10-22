# frozen_string_literal: true

module Shaka
  module Install
    # Where the official installation keeps its links and record. Every helper call reads these
    # at startup, so this file loads nothing else.
    module Locations
      HOSTS = { 'codex' => '.agents/skills', 'claude' => '.claude/skills', 'cursor' => '.cursor/skills',
                'opencode' => '.config/opencode/skills' }.freeze
      RECORD = 'shaka-install.json'
      # A replaced record is renamed RETIRED<UTC stamp>.json beside it, never deleted.
      RETIRED = 'shaka-install.retired-'
      # The default source checkout, under HOME. HOME/.agents holds settings and never a checkout.
      SOURCE = '.local/share/shaka/source'
      SETTINGS = '.agents'
    end
  end
end
