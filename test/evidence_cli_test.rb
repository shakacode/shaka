# frozen_string_literal: true

require_relative 'evidence_fixture'

class EvidenceCliTest < Minitest::Test
  include EvidenceFixture

  def test_help_exits_successfully
    capture_io { assert_equal 0, Shaka::Evidence::Command.run(%w[run --help]) }
    capture_io { assert_equal 0, Shaka::LocalReview.run(%w[check --help]) }
  end

  def test_run_reports_an_unconfigured_fixed_command
    with_checkout do |root, ref|
      _output, error = capture_io do
        assert_equal 1, Shaka::Evidence::Command.run(
          ['run', '--root', root, '--ref', ref, '--repository', 'shakacode/shaka', '--command', 'validate_local']
        )
      end
      assert_includes error, 'validate_local is not configured for this repository'
    end
  end

  def test_each_action_rejects_another_actions_flag
    with_checkout do |root, ref|
      common = ['--root', root, '--ref', ref, '--repository', 'shakacode/shaka']
      { 'run' => ['--command', 'validate', '--result', File.join(Dir.tmpdir, 'ignored.json')],
        'bind' => ['--command', 'validate'], 'verify' => ['--base', 'main'],
        'guard' => ['--validation', 'result.json'] }.each do |action, flags|
        _output, error = capture_io { assert_equal 1, Shaka::Evidence::Command.run([action, *common, *flags]) }
        assert_includes error, 'invalid option', action
      end
    end
  end

  def test_bind_rejects_result_inside_candidate_checkout
    with_checkout do |root, ref|
      path = File.join(root, 'result.json')
      File.write(path, JSON.generate(run_check(root, ref)))
      assert_raises(Shaka::Error) { Shaka::Evidence::Result.local_file!(root, path) }
    end
  end

  def test_bind_of_a_bind_output_binds_the_wrapped_result
    with_checkout do |root, ref|
      raw = run_check(root, ref)
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'bound.json')
        File.write(path, JSON.generate(bind(root, ref, ref, raw)))
        assert_equal raw, cli_bind(root, ref, path).fetch('original')
      end
    end
  end

  private

  def cli_bind(root, ref, path)
    arguments = ['bind', '--root', root, '--ref', ref, '--repository', 'shakacode/shaka', '--head', ref, '--result',
                 path]
    output, = capture_io { assert_equal 0, Shaka::Evidence::Command.run(arguments) }
    JSON.parse(output)
  end
end
