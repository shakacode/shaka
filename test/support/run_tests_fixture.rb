# frozen_string_literal: true

require 'open3'
require 'rbconfig'

# Test files and a launcher for RunTestsTest, which starts bin/run-tests in a temporary directory.
module RunTestsFixture
  RUNNER = File.expand_path('../../bin/run-tests', __dir__)

  private

  def latin1_fixture
    File.join(@directory, 'latin1_test.rb').tap do |path|
      File.write(path, <<~'RUBY')
        require 'minitest/autorun'

        class Latin1FixtureTest < Minitest::Test
          def test_latin1
            $stdout.binmode.write("caf\xE9\n".b)
            assert true
          end
        end
      RUBY
    end
  end

  def locale_fixture
    File.join(@directory, 'locale_test.rb').tap do |path|
      File.write(path, <<~RUBY)
        require 'minitest/autorun'

        class LocaleFixtureTest < Minitest::Test
          def test_utf8
            puts 'café'
            assert_equal Encoding::UTF_8, Encoding.default_external
          end
        end
      RUBY
    end
  end

  # Each test appends "PID class#test" to the marker file, so a test can see which worker ran it.
  def fixture(name, tests, failing: false)
    File.join(@directory, 'test', "#{name}_test.rb").tap do |path|
      File.write(path, "require 'minitest/autorun'\n\nclass #{name.capitalize}FixtureTest < Minitest::Test\n" \
                       "#{tests.map { |test| fixture_method(name, test, failing) }.join}end\n")
    end
  end

  def fixture_method(name, test, failing)
    <<~RUBY
      def test_#{test}
        File.write(ENV.fetch('MARKER'), "\#{Process.pid} #{name}##{test}\\n", mode: 'a')
        flunk '#{name} #{test} failed' if #{failing}
      end
    RUBY
  end

  # bin/validate starts the runner under bundle exec, so its workers load the bundle's Minitest.
  # With no files, the runner takes the whole suite: every fixture under the temporary test directory.
  def run_tests(files, workers:, env: {})
    env = { 'MARKER' => @marker, 'SHAKA_TEST_WORKERS' => workers.to_s, 'SHAKA_TEST_DURATIONS' => @durations,
            'BUNDLE_GEMFILE' => File.expand_path('../../Gemfile', __dir__) }.merge(env)
    Open3.capture2e(env, 'bundle', 'exec', RbConfig.ruby, RUNNER, *files, chdir: @directory)
  end

  # Every fixture test that ran, as "class#test", sorted; a test that ran twice appears twice.
  def tests_ran = File.readlines(@marker).map { it.split.last }.sort

  # The fixture names each worker ran, one sorted list per worker process.
  def workers_ran
    runs = File.readlines(@marker, chomp: true).map(&:split)
    runs.group_by(&:first).values.map { |rows| rows.map { it.last[/\w+/] }.uniq.sort }.sort
  end
end
