# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/defaults'
require 'shaka/repository_config'
require 'shaka/ci_review_wait'
require 'shaka/claim'
require 'shaka/pr_watch'
require 'shaka/local_review/runner'

class DefaultsTest < Minitest::Test
  # Each defaults.yml path and the constant that must read it.
  SOURCES = {
    %w[merge limits] => Shaka::MergeLimits::DEFAULTS,
    %w[prose_limits] => Shaka::ProseLimits::DEFAULTS,
    %w[pr_description opening_check] => Shaka::RepositoryConfig::OpeningSchema::DEFAULTS,
    %w[review post_implementation] => Shaka::RepositoryConfig::PostImplementationSchema::DEFAULTS,
    %w[wip] => Shaka::RepositoryConfig::DEFAULT_WIP,
    %w[pr_description] => Shaka::RepositoryConfig::DEFAULT_PR_DESCRIPTION,
    %w[review local_max_rounds] => Shaka::RepositoryConfig::ReviewLimit::DEFAULT,
    %w[review ci_review_wait] => Shaka::CiReviewWait::DEFAULT,
    %w[branches name] => Shaka::Claim::Names::DEFAULT,
    %w[runtime review_timeout_seconds deepseek/openrouter] => Shaka::OpenrouterReview::DEFAULT_TIMEOUT_SECONDS,
    %w[runtime pr_watch interval_seconds] => Shaka::PrWatch::DEFAULT_INTERVAL,
    %w[runtime pr_watch timeout_seconds] => Shaka::PrWatch::DEFAULT_TIMEOUT,
    %w[runtime pr_watch settle_seconds] => Shaka::PrWatch::DEFAULT_SETTLE
  }.freeze

  def test_code_defaults_come_from_the_packaged_file
    SOURCES.each do |keys, constant|
      expected = Shaka::Defaults.fetch(*keys)
      expected = expected.except('opening_check') if keys == %w[pr_description]
      assert_equal expected, constant, keys.join('.')
    end
  end

  def test_omitted_settings_resolve_to_the_file
    config = Shaka::RepositoryConfig.load(root: Dir.pwd, source: YAML.dump(minimal), available_commands: [])

    assert_equal Shaka::Defaults.fetch('review', 'ci_review_wait'), config.review.fetch('ci_review_wait')
    assert_equal Shaka::Defaults.fetch('review', 'local_max_rounds'), config.review.fetch('local_max_rounds')
    assert_equal Shaka::Defaults.fetch('pr_description', 'opening_check'), config.opening_check
  end

  def test_rejects_malformed_yaml
    error = assert_raises(Shaka::Error) { Shaka::Defaults.load("review: [\n") }
    assert_match(/Invalid .*defaults\.yml/, error.message)
  end

  def test_rejects_a_missing_or_unexpected_section
    source = File.read(Shaka::Defaults::PATH).sub(/^runtime:/, 'extra:')
    error = assert_raises(Shaka::Error) { Shaka::Defaults.load(source) }
    assert_match(/sections must be/, error.message)
  end

  def test_rejects_a_duplicate_key
    assert_raises(Shaka::Error) { Shaka::Defaults.load("review: {}\nreview: {}\n") }
  end

  def test_reports_a_missing_key_by_path
    error = assert_raises(Shaka::Error) { Shaka::Defaults.fetch('review', 'absent') }
    assert_match(/has no review\.absent/, error.message)
  end

  def test_reports_an_unreadable_file
    with_path('/nonexistent/defaults.yml') do
      error = assert_raises(Shaka::Error) { Shaka::Defaults.fetch('review') }
      assert_match(/built-in defaults are unreadable/, error.message)
    end
  end

  private

  def minimal
    { 'version' => 1, 'review' => { 'required' => 'none' }, 'merge' => { 'preference' => 'ask' } }
  end

  def with_path(path)
    saved = Shaka::Defaults.instance_variable_get(:@data)
    Shaka::Defaults.instance_variable_set(:@data, nil)
    Shaka::Defaults.send(:remove_const, :PATH)
    Shaka::Defaults.const_set(:PATH, path)
    yield
  ensure
    Shaka::Defaults.send(:remove_const, :PATH)
    Shaka::Defaults.const_set(:PATH, File.expand_path('../skills/shaka/config/defaults.yml', __dir__))
    Shaka::Defaults.instance_variable_set(:@data, saved)
  end
end
