# frozen_string_literal: true

require 'json'
require 'open3'

module Shaka
  module Evaluation
    # Keep platform credentials out of the replay and require a subscription login.
    module ReviewReplayLogin
      CREDENTIALS = %w[ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL OPENAI_API_KEY
                       OPENAI_BASE_URL CODEX_API_KEY CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX
                       CLAUDE_CODE_USE_FOUNDRY CLAUDE_CODE_OAUTH_TOKEN].to_h { |name| [name, nil] }.freeze

      private

      def verify_login
        return verify_claude if @host == 'claude-code'

        @environment['CODEX_HOME'] = copy_codex_login
        output, error, status = Open3.capture3(@environment, 'codex', 'login', 'status')
        return if status.success? && "#{output}\n#{error}".lines.any? { |line| line.strip == 'Logged in using ChatGPT' }

        raise IOError, 'Sign in to Codex with ChatGPT before replaying'
      end

      def copy_codex_login
        original = File.expand_path('auth.json', ENV.fetch('CODEX_HOME', '~/.codex'))
        home = File.join(@scratch, 'codex')
        Dir.mkdir(home, 0o700)
        copy_private(original, File.join(home, 'auth.json'))
        home
      end

      def copy_private(source, destination)
        File.open(destination, 'wx', 0o600) do |file|
          File.open(source, 'rb') { |input| IO.copy_stream(input, file) }
          file.fsync
        end
      end

      def verify_claude
        output, _error, status = Open3.capture3(@environment, 'claude', 'auth', 'status', '--json')
        login = JSON.parse(output)
        return if status.success? && login['loggedIn'] && login['authMethod'] == 'claude.ai' &&
                  login['apiProvider'] == 'firstParty'

        raise IOError, 'Sign in to Claude Code with a Claude subscription before replaying'
      end
    end
  end
end
