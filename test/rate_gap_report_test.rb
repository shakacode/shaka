# frozen_string_literal: true

require_relative 'missing_rates_test'
require_relative '../skills/shaka/lib/shaka/usage/rate_gap_report'

module RateGapReportFixture
  class GitHub
    attr_accessor :issues, :card, :failure
    attr_reader :calls, :requests

    def initialize
      @issues = []
      @calls = []
      @requests = []
      @card = File.read(Shaka::RateCard::INSTALLED_PATH)
    end

    def verify_repository!
      @calls << :identity
      raise Shaka::Error, '/private/token secret' if @failure == :identity
    end

    def gh(*arguments)
      path = arguments.last
      @calls << path
      raise Shaka::Error, 'private transcript' if @failure == :read
      return 'invalid json' if @failure == :json
      return JSON.generate([]) if @failure == :empty
      return JSON.generate([{ sha: 'a' * 40 }]) if path.include?('commits?')
      return JSON.generate({ encoding: 'base64', content: [@card].pack('m0') }) if path.include?('contents/')

      JSON.generate(@issues)
    end

    def create(request)
      verify_repository!
      raise Shaka::Error, '/private/source' if @failure == :create || (@failure == :second_create && @requests.any?)

      @requests << request
      title, body = request.split("\n", 2)
      @issues << { 'title' => title, 'body' => body, 'html_url' => 'https://github.com/shakacode/shaka/issues/999' }
      @issues.last['html_url']
    end
  end

  def record
    { 'configuration' => %w[openai gpt-99-sol],
      'usage' => { 'input_tokens' => 100, 'cached_input_tokens' => 0,
                   'cache_write_input_tokens' => 0, 'output_tokens' => 10 } }
  end

  def setup
    @github = GitHub.new
  end

  def report(records = [record], catalog: 'gpt-99-sol')
    Shaka::RateGapReport.new(records, inclusive_input: true, rate_card: Shaka::RateCard.installed,
                                      github: @github, catalog: ->(_url) { catalog }).report
  end
end

class RateGapReportTest < Minitest::Test
  include RateGapReportFixture

  def test_public_safe_reproduction_and_repeat_runs_reuse_links
    assert_includes report, '/issues/999'
    assert_equal 2, @github.requests.size
    report
    assert_equal 2, @github.requests.size
    assert_equal :identity, @github.calls.first
  end

  def test_filed_text_is_a_public_safe_synthetic_reproduction
    response = record
    response['prompt'] = '/private/customer transcript native-id'
    response['usage']['input_tokens'] = 987_654
    report([response])
    body = @github.requests.first
    %w[private customer transcript native-id 987654 987_654].each { |text| refute_includes body, text }
    assert_includes body, 'input_tokens=100'
    assert_includes body, 'reviewed PR'
    assert_includes body, 'a' * 40
  end

  def test_a_later_catalog_failure_keeps_the_created_issue_link
    reporter = Shaka::RateGapReport.new([record], inclusive_input: true, rate_card: Shaka::RateCard.installed,
                                                  github: @github, catalog: method(:failing_credit_catalog))
    text = reporter.report
    assert_includes text, '/issues/999'
    assert_includes text, 'failed during public model verification'
    refute_includes text, 'private'
  end

  def failing_credit_catalog(url)
    raise IOError, 'private catalog error' if url.include?('learn.chatgpt.com')

    'gpt-99-sol'
  end

  def test_a_later_filing_failure_keeps_the_created_issue_link
    @github.failure = :second_create
    text = report
    assert_includes text, '/issues/999'
    assert_includes text, 'failed during issue creation'
    assert_equal 1, @github.requests.size
  end

  def test_closed_legacy_report_is_reused
    @github.issues = [{ 'title' => 'Add gpt-99-sol cost rates', 'state' => 'closed',
                        'html_url' => 'https://github.com/shakacode/shaka/issues/88' }]
    assert_includes report, '/issues/88'
    assert_empty @github.requests
  end

  def test_stale_installation_checks_current_card_and_does_not_file
    @github.card = @github.card.sub('    gpt-6.1-sol:', '    gpt-99-sol:')
    assert_includes report, 'already prices'
    assert_empty @github.requests
    assert(@github.calls.any? { |call| call.to_s.include?("ref=#{'a' * 40}") })
  end

  def test_unknown_public_model_does_not_file
    assert_includes report(catalog: 'gpt-99-sol-private'), 'not verified'
    assert_empty @github.requests
  end

  def test_unpublished_credit_scenario_does_not_file_a_second_issue
    catalog = ->(url) { url.include?('learn.chatgpt.com') ? 'other models' : 'gpt-99-sol' }
    reporter = Shaka::RateGapReport.new([record], inclusive_input: true, rate_card: Shaka::RateCard.installed,
                                                  github: @github, catalog:)
    assert_includes reporter.report, 'not verified'
    assert_equal 1, @github.requests.size
    assert_includes @github.requests.first, '(api)'
  end

  def test_every_github_failure_is_visible_and_redacted
    %i[identity read json empty create].each do |failure|
      @github.failure = failure
      text = report
      assert_includes text, 'failed during'
      assert_includes text, 'estimates remain unchanged'
      refute_includes text, 'private'
      assert_empty @github.requests
    end
  end

  def test_invalid_current_card_and_untrusted_issue_url_fail_without_filing
    @github.card = 'openai: malformed'
    assert_includes report, 'failed during trusted rate-card read'
    @github.card = File.read(Shaka::RateCard::INSTALLED_PATH)
    @github.issues = [{ 'title' => 'gpt-99-sol pricing', 'html_url' => 'https://private.example/' }]
    assert_includes report, 'failed during duplicate lookup'
    assert_empty @github.requests
  end

  def test_listing_limit_and_catalog_failure_do_not_file
    @github.issues = Array.new(100) { { 'title' => 'unrelated' } }
    assert_includes report, 'failed during duplicate lookup'
    @github.issues = []
    reporter = Shaka::RateGapReport.new([record], inclusive_input: true, rate_card: Shaka::RateCard.installed,
                                                  github: @github, catalog: ->(_) { raise IOError, 'private' })
    assert_includes reporter.report, 'failed during public model verification'
    assert_empty @github.requests
  end
end

class RateGapTransportTest < Minitest::Test
  include RateGapReportFixture

  def test_dns_failure_in_the_real_catalog_reader_preserves_reporting
    reporter = Shaka::RateGapReport.new([record], inclusive_input: true, rate_card: Shaka::RateCard.installed,
                                                  github: @github)
    with_http_result(SocketError.new('private resolver detail')) do
      text = reporter.report
      assert_includes text, 'failed during public model verification'
      refute_includes text, 'private'
    end
  end

  def test_non_success_http_response_preserves_reporting
    reporter = Shaka::RateGapReport.new([record], inclusive_input: true, rate_card: Shaka::RateCard.installed,
                                                  github: @github)
    with_http_result(Net::HTTPNotFound.new('1.1', '404', 'Not found')) do
      assert_includes reporter.report, 'failed during public model verification'
      assert_empty @github.requests
    end
  end

  def test_different_scenarios_do_not_reuse_an_automatically_filed_title
    report(catalog: 'gpt-99-sol')
    api_only = @github.issues.first
    @github.issues = [api_only]
    @github.requests.clear
    report
    assert_equal 1, @github.requests.size
    assert_includes @github.requests.first, '(credits)'
  end

  def test_malformed_http_response_preserves_reporting
    reporter = Shaka::RateGapReport.new([record], inclusive_input: true, rate_card: Shaka::RateCard.installed,
                                                  github: @github)
    with_http_result(Net::HTTPBadResponse.new('private status line')) do
      text = reporter.report
      assert_includes text, 'failed during public model verification'
      refute_includes text, 'private'
    end
  end

  def base_model_report(catalog)
    response = record.merge('configuration' => %w[openai gpt-7])
    Shaka::RateGapReport.new([response], inclusive_input: true, rate_card: Shaka::RateCard.installed,
                                         github: @github, catalog: ->(_) { catalog }).report
  end

  def test_title_for_a_variant_does_not_suppress_the_base_model_report
    @github.issues = [{ 'title' => 'Add GPT-7 mini rates',
                        'html_url' => 'https://github.com/shakacode/shaka/issues/88' }]
    assert_includes base_model_report('GPT-7'), '/issues/999'
    assert_equal 2, @github.requests.size
  end

  def test_common_punctuation_in_a_legacy_title_is_recognized
    ['Missing rates: gpt-7 (api)', 'Add pricing for gpt-7.', 'gpt-7: add rates'].each do |title|
      @github.issues = [{ 'title' => title, 'html_url' => 'https://github.com/shakacode/shaka/issues/88' }]
      assert_includes base_model_report('GPT-7'), '/issues/88'
      assert_empty @github.requests
    end
  end

  def test_catalog_variant_does_not_verify_the_base_model
    assert_includes base_model_report('GPT-7 mini'), 'not verified'
    assert_empty @github.requests
  end

  def with_http_result(result)
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) do |*|
      raise result if result.is_a?(Exception)

      result
    end
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end
end
