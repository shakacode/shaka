# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'socket'
require_relative '../eval/lib/shaka/evaluation/probe_container'

module LocalEvaluationProbeHelpers
  ROOT = File.expand_path('..', __dir__)
  FIXTURE = File.join(ROOT, 'eval/fixtures/local_evaluation/probe')
  TRUSTED_SKILL = '/opt/trusted/shaka'

  def new_container
    Shaka::Evaluation::ProbeContainer.new(root: ROOT, trusted_skill: TRUSTED_SKILL)
  end

  def fixture_files(root)
    Dir.glob('**/*', File::FNM_DOTMATCH, base: root)
       .reject { |path| File.directory?(File.join(root, path)) }
       .sort
  end

  def clean_environment(home, fake_bin)
    { 'HOME' => home, 'PATH' => "#{fake_bin}:#{ENV.fetch('PATH')}", 'GH_TOKEN' => nil,
      'GITHUB_TOKEN' => nil, 'SSH_AUTH_SOCK' => nil }
  end

  def write_executable(directory, name, body)
    path = File.join(directory, name)
    File.write(path, body)
    FileUtils.chmod(0o755, path)
  end
end

class LocalEvaluationProbeContainerPlanTest < Minitest::Test
  include LocalEvaluationProbeHelpers

  def setup
    @container = new_container
  end

  def test_create_plan_exposes_only_the_fixture_helper_and_disposable_workspace
    command = @container.create_command('shaka-slice0-probe-test')
    mounts = command.each_index.filter_map { |index| command[index + 1] if command[index] == '--mount' }

    assert_equal expected_mounts, mounts
    assert_includes command, '--read-only'
    assert_includes command, 'no-new-privileges'
    assert_includes command, 'ALL'
    refute(command.any? { |argument| argument.include?('.ssh') || argument.include?('docker.sock') })
  end

  def test_lifecycle_commands_use_only_the_disposable_name_and_local_image
    assert_equal ['docker', 'build', '--tag', 'shaka-slice0-probe:local',
                  File.join(ROOT, 'eval/docker/slice-0-probe')], @container.build_command
  end

  def test_create_plan_keeps_credentials_out_of_arguments_and_uses_ephemeral_home
    command = @container.create_command('shaka-slice0-probe-test')

    assert_includes command, 'HOME=/home/shaka'
    assert_includes command, '/home/shaka:rw,noexec,nosuid,nodev,mode=0700,uid=100,gid=101'
    refute(command.any? { |argument| argument.match?(/token|github_pat_|ssh_auth_sock/i) })
  end

  def test_auth_and_preflight_keep_sensitive_values_on_stdin
    name = 'shaka-slice0-probe-test'

    assert_equal %W[docker exec #{name} probe-reset], @container.prepare_command(name)
    assert_equal %w[docker exec -i shaka-slice0-probe-test gh auth login --hostname github.com --with-token],
                 @container.auth_command(name)
    assert_equal %w[docker exec shaka-slice0-probe-test gh auth setup-git],
                 @container.git_auth_command(name)
    assert_equal ['docker', 'exec', '-i', name, 'probe-preflight', 'shakacode/public-probe',
                  'shaka-eval-machine'],
                 @container.preflight_command(name, target: 'shakacode/public-probe',
                                                    login: 'shaka-eval-machine')
  end

  def test_owner_side_preflight_confirms_the_private_sibling
    assert_equal %w[gh api user --jq .login], @container.owner_identity_command
    assert_equal %w[gh api repos/shakacode/private-sibling --jq .visibility],
                 @container.owner_repository_command('shakacode/private-sibling')
    assert_raises(ArgumentError) { @container.owner_repository_command('shakacode/one/two') }
    assert_raises(ArgumentError) { @container.owner_repository_command('../..') }
  end

  def test_candidate_checkout_cannot_supply_the_trusted_helper
    candidate_skill = File.join(ROOT, 'skills/shaka')
    container = Shaka::Evaluation::ProbeContainer.new(root: ROOT, trusted_skill: candidate_skill)

    error = assert_raises(ArgumentError) { container.create_command('shaka-slice0-probe-test') }
    assert_match(/outside the candidate checkout/, error.message)

    ancestor = Shaka::Evaluation::ProbeContainer.new(root: ROOT, trusted_skill: File.dirname(ROOT))
    assert_raises(ArgumentError) { ancestor.create_command('shaka-slice0-probe-test') }
  end

  def test_preflight_command_rejects_an_invalid_login
    assert_raises(ArgumentError) do
      @container.preflight_command('shaka-slice0-probe-test', target: 'shakacode/probe', login: '../owner')
    end
  end

  def test_cleanup_plan_can_target_only_a_slice_zero_probe_container
    assert_equal [
      %w[docker rm --force --volumes shaka-slice0-probe-test]
    ], @container.cleanup_commands('shaka-slice0-probe-test')

    error = assert_raises(ArgumentError) { @container.cleanup_commands('shared-development') }
    assert_match(/disposable Slice 0 probe name/, error.message)
  end

  private

  def expected_mounts
    ["type=bind,src=#{FIXTURE},dst=/seed/probe,readonly",
     "type=bind,src=#{TRUSTED_SKILL},dst=/opt/shaka,readonly",
     'type=volume,dst=/workspace']
  end
end

class LocalEvaluationProbeResetTest < Minitest::Test
  include LocalEvaluationProbeHelpers

  def test_reset_replaces_history_and_preserves_fixture_dotfiles
    script = File.join(ROOT, 'eval/docker/slice-0-probe/probe-reset')

    Dir.mktmpdir('probe-reset') do |directory|
      seed, destination = reset_fixture(directory)
      stdout, stderr, status = Open3.capture3(script, seed, destination)
      assert_predicate status, :success?, "#{stdout}\n#{stderr}"
      assert_equal %w[.ruby-version lib/color.rb], fixture_files(destination)
      assert_equal "3.4.6\n", File.read(File.join(destination, '.ruby-version'))
    end
  end

  private

  def reset_fixture(directory)
    seed = File.join(directory, 'seed')
    destination = File.join(directory, 'repo')
    FileUtils.mkdir_p(File.join(seed, 'lib'))
    FileUtils.mkdir_p(destination)
    File.write(File.join(seed, '.ruby-version'), "3.4.6\n")
    File.write(File.join(seed, 'lib/color.rb'), "module Color; end\n")
    File.write(File.join(destination, 'solved-history.txt'), "must disappear\n")
    [seed, destination]
  end
end

module LocalEvaluationPreflightHelpers
  private

  def with_preflight(ssh_body, stdin_data: "shakacode/private-sibling\n", environment: {}, docker_socket: nil)
    Dir.mktmpdir('probe-preflight') do |directory|
      fake_bin = create_fake_tools(directory, ssh_body)
      env = clean_environment(directory, fake_bin).merge(environment)
      yield(*Open3.capture3(env, *preflight_command(directory, docker_socket), stdin_data:))
    end
  end

  def create_fake_tools(directory, ssh_body)
    fake_bin = File.join(directory, 'bin')
    FileUtils.mkdir_p(fake_bin)
    write_executable(fake_bin, 'gh', fake_gh)
    write_executable(fake_bin, 'git', fake_git)
    write_executable(fake_bin, 'ssh', ssh_body)
    fake_bin
  end

  def preflight_command(directory, docker_socket)
    root = LocalEvaluationProbeHelpers::ROOT
    [File.join(root, 'eval/docker/slice-0-probe/probe-preflight'),
     'shakacode/public-probe', 'shaka-eval-machine', docker_socket || File.join(directory, 'missing-docker.sock')]
  end

  def fake_gh
    <<~SH
      #!/bin/sh
      case "$*" in
        'api user --jq .login') echo shaka-eval-machine ;;
        'api repos/shakacode/public-probe') exit 0 ;;
        'api repos/shakacode/private-sibling')
          [ "${FAKE_PRIVATE_API:-deny}" = allow ] && exit 0
          [ "${FAKE_PRIVATE_API:-deny}" = outage ] && echo 'gh: service unavailable (HTTP 503)' >&2 && exit 1
          echo 'gh: Not Found (HTTP 404)' >&2
          exit 1 ;;
        *) exit 2 ;;
      esac
    SH
  end

  def fake_git
    <<~SH
      #!/bin/sh
      case "$*" in
        *shakacode/public-probe.git*) exit 0 ;;
        *shakacode/private-sibling.git*)
          [ "${FAKE_PRIVATE_GIT:-deny}" = allow ] && exit 0
          echo 'remote: Repository not found.' >&2
          exit 1 ;;
        *) exit 1 ;;
      esac
    SH
  end

  def successful_ssh
    <<~SH
      #!/bin/sh
      echo 'Hi machine! You have successfully authenticated, but GitHub does not provide shell access.' >&2
      exit 1
    SH
  end

  def denied_ssh = "#!/bin/sh\necho 'Permission denied (publickey).' >&2\nexit 255\n"

  def expected_success
    <<~OUTPUT
      identity=PASS
      target=PASS
      target_https=PASS
      private_api=DENIED
      private_https=DENIED
      alternate_ssh=DENIED
      preflight=PASS
    OUTPUT
  end
end

class LocalEvaluationProbePreflightTest < Minitest::Test
  include LocalEvaluationProbeHelpers
  include LocalEvaluationPreflightHelpers

  def test_preflight_proves_the_scoped_pat_has_no_alternate_private_access
    with_preflight(denied_ssh) do |stdout, stderr, status|
      assert_predicate status, :success?, "#{stdout}\n#{stderr}"
      assert_equal expected_success, stdout
      refute_includes "#{stdout}\n#{stderr}", 'private-sibling'
    end
  end

  def test_preflight_refuses_an_available_ssh_identity
    with_preflight(successful_ssh) do |_stdout, stderr, status|
      refute_predicate status, :success?
      assert_match(/alternate GitHub SSH credential is available/, stderr)
    end
  end

  def test_preflight_accepts_private_repository_input_without_a_trailing_newline
    with_preflight(denied_ssh, stdin_data: 'shakacode/private-sibling') do |_out, err, status|
      assert_predicate status, :success?, err
    end
  end

  def test_preflight_rejects_a_malformed_private_repository
    with_preflight(denied_ssh, stdin_data: 'shakacode/one/two') do |_out, err, status|
      refute_predicate status, :success?
      assert_match(%r{private sibling repository must be OWNER/REPOSITORY}, err)
    end
  end

  def test_preflight_requires_a_sibling_in_the_target_owner
    with_preflight(denied_ssh, stdin_data: 'other/private-sibling') do |_out, err, status|
      refute_predicate status, :success?
      assert_match(/same owner as the target repository/, err)
    end
  end

  def test_preflight_reports_empty_stdin
    with_preflight(denied_ssh, stdin_data: '') do |_out, err, status|
      refute_predicate status, :success?
      assert_match(/private sibling repository is required on stdin/, err)
    end
  end

  def test_preflight_refuses_an_inconclusive_ssh_failure
    with_preflight("#!/bin/sh\necho 'Could not resolve hostname github.com' >&2\nexit 255\n") do |_out, err, status|
      refute_predicate status, :success?
      assert_match(/GitHub SSH denial was inconclusive/, err)
    end
  end

  def test_preflight_refuses_inconclusive_private_api_failures
    with_preflight("#!/bin/sh\nexit 255\n", environment: { 'FAKE_PRIVATE_API' => 'outage' }) do |_out, err, status|
      refute_predicate status, :success?
      assert_match(/private sibling API denial was inconclusive/, err)
    end
  end

  def test_preflight_refuses_private_access_that_succeeds
    { 'FAKE_PRIVATE_API' => 'allow', 'FAKE_PRIVATE_GIT' => 'allow' }.each do |variable, value|
      with_preflight("#!/bin/sh\nexit 255\n", environment: { variable => value }) do |_out, err, status|
        refute_predicate status, :success?
        assert_match(/can (?:read|clone) a private sibling/, err)
      end
    end
  end

  def test_preflight_rejects_inherited_credentials
    %w[GH_TOKEN GITHUB_TOKEN SSH_AUTH_SOCK].each do |variable|
      with_preflight("#!/bin/sh\nexit 255\n", environment: { variable => 'present' }) do |_out, err, status|
        refute_predicate status, :success?
        assert_match(/must not be inherited/, err)
      end
    end
  end

  def test_preflight_rejects_a_mounted_docker_socket
    Dir.mktmpdir('probe-socket') do |directory|
      UNIXServer.open(socket = File.join(directory, 'docker.sock')) do
        with_preflight("#!/bin/sh\nexit 255\n", docker_socket: socket) do |_out, err, status|
          refute_predicate status, :success?
          assert_match(/Docker socket is available/, err)
        end
      end
    end
  end
end

class LocalEvaluationProbeCliTest < Minitest::Test
  include LocalEvaluationProbeHelpers

  def test_preflight_wrapper_accepts_rest_private_visibility_and_streams_the_sibling
    Dir.mktmpdir('probe-cli') do |directory|
      stdout, stderr, status = run_preflight_wrapper(directory)
      assert_predicate status, :success?, stderr
      assert_equal "wrapper=PASS\n", stdout
    end
  end

  def test_preflight_wrapper_refuses_machine_owner_or_nonprivate_sibling
    [{ 'FAKE_OWNER_LOGIN' => 'shaka-eval-machine' }, { 'FAKE_VISIBILITY' => 'public' }].each do |environment|
      Dir.mktmpdir('probe-cli') do |directory|
        _stdout, stderr, status = run_preflight_wrapper(directory, environment:)
        refute_predicate status, :success?
        assert_match(/must differ|could not verify/, stderr)
      end
    end
  end

  private

  def run_preflight_wrapper(directory, environment: {})
    fake_bin = File.join(directory, 'bin')
    FileUtils.mkdir_p(fake_bin)
    write_executable(fake_bin, 'gh', owner_gh)
    write_executable(fake_bin, 'docker', docker_preflight)
    command = [File.join(ROOT, 'eval/bin/slice-0-probe-container'), 'preflight',
               'shaka-slice0-probe-test', 'shakacode/public-probe', 'shaka-eval-machine']
    Open3.capture3(clean_environment(directory, fake_bin).merge(environment), *command,
                   stdin_data: "shakacode/private-sibling\n")
  end

  def owner_gh
    <<~SH
      #!/bin/sh
      [ "$*" = 'api user --jq .login' ] && echo "${FAKE_OWNER_LOGIN:-justin808}" && exit 0
      [ "$*" = 'api repos/shakacode/private-sibling --jq .visibility' ] && echo "${FAKE_VISIBILITY:-private}" && exit 0
      exit 2
    SH
  end

  def docker_preflight
    <<~SH
      #!/bin/sh
      [ "$*" = 'exec -i shaka-slice0-probe-test probe-preflight shakacode/public-probe shaka-eval-machine' ] || exit 4
      IFS= read -r repository
      [ "$repository" = shakacode/private-sibling ] || exit 3
      echo wrapper=PASS
    SH
  end
end
