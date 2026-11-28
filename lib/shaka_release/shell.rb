# frozen_string_literal: true

require 'open3'

module ShakaRelease
  # Runs release commands with the caller's environment and refuses on any failure.
  module Shell
    private

    def run!(env, *command, failure: nil)
      output, error, status = Open3.capture3(env, *command)
      refuse "#{command.first(3).join(' ')} failed: #{(error + output).strip}#{"\n#{failure}" if failure}" unless
        status.success?
      output
    end

    def refuse(message) = raise(Shaka::Error, message)
  end
end
