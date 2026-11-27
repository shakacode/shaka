# frozen_string_literal: true

require 'json'
require 'open3'
require 'tmpdir'

module Shaka
  module Evaluation
    # The subscription client can open its login. Its command tools get only the fixture and basic OS reads.
    module ReviewReplaySandbox
      PROFILE = 'shaka-review-replay'
      TOOLS = File.expand_path('../../../bin/replay-tools', __dir__)

      module_function

      def profile(fixture)
        fixture = File.realpath(fixture)
        ['-c', %(permissions.#{PROFILE}.filesystem={":minimal"="read",#{fixture.to_json}="read"}),
         '-c', "permissions.#{PROFILE}.network.enabled=false"]
      end

      def exec_arguments(fixture, legacy)
        arguments = legacy.dup
        unless arguments.shift(3) == %w[exec -s read-only]
          raise ArgumentError, 'The installed helper did not request the expected Codex read-only launch'
        end

        ['-a', 'never', 'exec', *profile(fixture), '-c', "default_permissions=#{PROFILE.to_json}",
         '-c', 'web_search="disabled"', *arguments]
      end

      def sandbox_arguments(fixture, command)
        ['sandbox', *profile(fixture), '-P', PROFILE, '-C', fixture, '--', *command]
      end

      def codex(path)
        executable = absolute_path(path).map { |directory| File.join(directory, 'codex') }
                                        .find { |file| File.file?(file) && File.executable?(file) }
        raise IOError, 'Codex must be installed on an absolute PATH entry' unless executable

        File.realpath(executable)
      end

      def environment(executable, fixture, path)
        { 'SHAKA_REPLAY_CODEX' => executable, 'SHAKA_REPLAY_FIXTURE' => File.realpath(fixture),
          'PATH' => [TOOLS, *absolute_path(path)].join(File::PATH_SEPARATOR) }
      end

      def verify(executable, environment, scratch)
        Dir.mktmpdir('sandbox-check-', scratch) do |directory|
          fixture = File.join(directory, 'fixture')
          home = File.join(directory, 'codex-home')
          Dir.mkdir(fixture, 0o700)
          Dir.mkdir(home, 0o700)
          verify_canaries(executable, environment.merge('CODEX_HOME' => home), fixture, home)
        end
      end

      def verify_canaries(executable, environment, fixture, home)
        control = canary(fixture, 'control')
        private_files = [canary(home, 'auth.json'), canary(File.dirname(fixture), 'prior-transcript.jsonl')]
        return if probe(executable, environment, fixture, control) == :readable &&
                  private_files.all? { |path| probe(executable, environment, fixture, path) == :denied }

        raise IOError, 'Codex replay requires a verified fixture-only command sandbox'
      end

      def canary(directory, filename)
        path = File.join(directory, filename)
        File.write(path, "replay-canary\n", perm: 0o600)
        path
      end

      def probe(executable, environment, fixture, path)
        arguments = sandbox_arguments(fixture, ['/bin/cat', path])
        output, error, status = Open3.capture3(environment, executable, *arguments)
        return :readable if status.success? && output == "replay-canary\n"
        return :denied if status.exitstatus == 1 && output.empty? && permission_denial?(error, path)

        :inconclusive
      end

      def permission_denial?(error, path)
        error.lines.any? do |line|
          line.include?(path) && line.strip.end_with?('Permission denied', 'Operation not permitted')
        end
      end

      def absolute_path(path)
        path.split(File::PATH_SEPARATOR).select { |directory| directory.start_with?(File::SEPARATOR) }
      end
    end
  end
end
