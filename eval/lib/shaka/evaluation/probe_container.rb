# frozen_string_literal: true

module Shaka
  module Evaluation
    # Builds commands for the disposable, credential-isolated Slice 0 probe container.
    class ProbeContainer
      IMAGE = 'shaka-slice0-probe:local'
      NAME = /\Ashaka-slice0-probe-[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/

      def initialize(root:, trusted_skill:)
        @root = File.expand_path(root)
        @trusted_skill = File.expand_path(trusted_skill) if trusted_skill
      end

      def build_command
        ['docker', 'build', '--tag', IMAGE, File.join(@root, 'eval/docker/slice-0-probe')]
      end

      def start_command(name) = ['docker', 'start', validate_name!(name)]
      def shell_command(name) = ['docker', 'exec', '-it', validate_name!(name), 'sh']
      def container_inspect_command(name) = ['docker', 'container', 'inspect', validate_name!(name)]

      def create_command(name)
        validate_name!(name)
        validate_mount_path!(fixture)
        trusted_skill = validate_trusted_skill!
        ['docker', 'create', '--name', name, '--hostname', 'slice0-probe',
         *security_options, *mount_options(trusted_skill),
         '--env', 'HOME=/home/shaka', '--env', 'TMPDIR=/workspace/tmp',
         '--env', 'GIT_TERMINAL_PROMPT=0',
         IMAGE, 'sleep', 'infinity']
      end

      def prepare_command(name) = ['docker', 'exec', validate_name!(name), 'probe-reset']

      def auth_command(name)
        validate_name!(name)
        %W[docker exec -i #{name} gh auth login --hostname github.com --with-token]
      end

      def git_auth_command(name)
        validate_name!(name)
        %W[docker exec #{name} gh auth setup-git]
      end

      def owner_identity_command = %w[gh api user --jq .login]

      def owner_repository_command(repository)
        validate_repository!(repository)
        ['gh', 'api', "repos/#{repository}", '--jq', '.visibility']
      end

      def preflight_command(name, target:, login:)
        validate_name!(name)
        validate_repository!(target)
        validate_login!(login)
        ['docker', 'exec', '-i', name, 'probe-preflight', target, login]
      end

      def cleanup_commands(name)
        validate_name!(name)
        [%W[docker rm --force --volumes #{name}]]
      end

      private

      def fixture = File.join(@root, 'eval/fixtures/local_evaluation/probe')

      def security_options
        ['--read-only', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
         '--network', 'bridge', '--pids-limit', '256', '--memory', '1g', '--cpus', '2',
         '--tmpfs', '/home/shaka:rw,noexec,nosuid,nodev,mode=0700,uid=100,gid=101',
         '--tmpfs', '/usr/local/bundle:rw,exec,nosuid,nodev,mode=0700,uid=100,gid=101',
         '--tmpfs', '/tmp:rw,noexec,nosuid,nodev']
      end

      def mount_options(trusted_skill)
        ['--mount', "type=bind,src=#{fixture},dst=/seed/probe,readonly",
         '--mount', "type=bind,src=#{trusted_skill},dst=/opt/shaka,readonly",
         '--mount', 'type=volume,dst=/workspace']
      end

      def validate_name!(name)
        return name if NAME.match?(name)

        raise ArgumentError, 'Expected a disposable Slice 0 probe name beginning with shaka-slice0-probe-'
      end

      def validate_trusted_skill!
        raise ArgumentError, 'Trusted Shaka helper is required' unless @trusted_skill

        root = canonical(@root)
        trusted = canonical(@trusted_skill)
        validate_mount_path!(trusted)
        validate_nonoverlap!(root, trusted)

        helper = File.join(trusted, 'scripts/shaka')
        valid_helper = File.file?(helper) && File.executable?(helper) && !File.symlink?(helper)
        valid_helper &&= contains?(trusted, File.realpath(helper))
        raise ArgumentError, 'Trusted Shaka helper must contain executable scripts/shaka' unless valid_helper

        trusted
      end

      def validate_repository!(repository)
        segments = repository.split('/', -1)
        return if %r{\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z}.match?(repository) &&
                  !segments.intersect?(%w[. ..])

        raise ArgumentError, 'Expected OWNER/REPOSITORY'
      end

      def validate_login!(login)
        return if /\A[A-Za-z0-9-]+\z/.match?(login)

        raise ArgumentError, 'Expected a GitHub login'
      end

      def canonical(path) = File.exist?(path) ? File.realpath(path) : path

      def validate_mount_path!(path)
        return unless path.match?(/[,"\r\n]/)

        raise ArgumentError, 'Docker mount source contains an unsupported character'
      end

      def validate_nonoverlap!(root, trusted)
        return unless contains?(root, trusted) || contains?(trusted, root)

        raise ArgumentError, 'Trusted Shaka helper must resolve outside the candidate checkout'
      end

      def contains?(parent, child)
        parent == File::SEPARATOR || child == parent || child.start_with?("#{parent}/")
      end
    end
  end
end
