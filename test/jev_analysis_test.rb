# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'rbconfig'
require_relative '../skills/shaka-jev/lib/shaka_jev/analysis'

class JevAnalysisTest < Minitest::Test
  HEAD = 'a' * 40
  URL = 'https://github.com/shakacode/shaka/pull/302'
  EVIDENCE = 'Public validation and review evidence.'
  OUTPUT = {
    model: 'jev-1.13.0',
    answers: {
      validation_supported: { type: 'noul', noul: 0.91 },
      material_concern_open: { type: 'noul', noul: 0.13 }
    },
    usage: { input_tokens: 2500, output_tokens: 25 }
  }.freeze

  def test_sends_one_request_with_fixed_questions_and_reports_usage
    result, sent = run_valid_request
    assert_request(sent)
    assert_result(result)
  end

  def run_valid_request
    sent = nil
    client = lambda do |uri, request|
      sent = [uri, request]
      response(200, OUTPUT)
    end
    public_repository = ->(owner, repo) { [owner, repo] == %w[shakacode shaka] }
    result = analyzer(api_key: 'test-key', client: client, public_repository: public_repository).call(
      pr_url: URL, head: HEAD, evidence: EVIDENCE
    )
    [result, sent]
  end

  def test_rejects_missing_key_before_sending
    client = ->(*) { flunk 'must not send' }
    assert_raises(ShakaJev::Error) do
      analyzer(api_key: '', client: client).call(pr_url: URL, head: HEAD, evidence: 'Public')
    end
  end

  def test_rejects_missing_response_fields_and_wrong_answer_type
    malformed = [OUTPUT.merge(model: ''), OUTPUT.merge(usage: { input_tokens: -1 }), [], OUTPUT.except(:usage),
                 invalid_answer(type: 'text', noul: 0.5), invalid_answer(type: 'noul', noul: 1.5)]
    malformed.each do |body|
      client = ->(*) { response(200, body) }
      assert_raises(ShakaJev::Error) { analyzer(api_key: 'test-key', client: client).call(**target) }
    end
  end

  def test_api_errors_expose_status_without_response_body
    client = ->(*) { response(401, { secret: 'must not appear' }) }
    error = assert_raises(ShakaJev::Error) do
      analyzer(api_key: 'test-key', client: client).call(**target)
    end
    assert_match(/401/, error.message)
    refute_match(/secret/, error.message)
  end

  def test_private_or_unverifiable_repository_is_not_sent
    client = ->(*) { flunk 'must not send' }
    error = assert_raises(ShakaJev::Error) do
      analyzer(api_key: 'test-key', client: client, public_repository: ->(*) { false }).call(**target)
    end
    assert_match(/verified public/, error.message)
  end

  def test_network_error_is_reported_without_backtrace
    client = ->(*) { raise SocketError, 'DNS failure' }
    error = assert_raises(ShakaJev::Error) { analyzer(api_key: 'test-key', client: client).call(**target) }
    assert_match(/Jev request failed: SocketError/, error.message)
    refute_match(/DNS failure/, error.message)
  end

  def test_invalid_target_or_evidence_is_not_sent
    client = ->(*) { flunk 'must not send' }
    invalid = [{ pr_url: URL.sub('/pull/', '/issues/') }, { pr_url: URL.sub('/shakacode/', '/-shakacode/') },
               { head: 'abc123' }, { evidence: '   ' }, { evidence: 'x' * 65_537 },
               { evidence: (+"\xFF").force_encoding(Encoding::UTF_8) }]
    invalid.each do |change|
      assert_raises(ShakaJev::Error) do
        analyzer(api_key: 'test-key', client: client).call(**target, **change)
      end
    end
  end

  private

  def assert_request(sent)
    payload = JSON.parse(sent.last.body)
    observed = [sent.first.to_s, sent.last['Authorization'], payload.fetch('model'),
                payload.fetch('questions').keys.sort]
    expected = ['https://api.typesafe.ai/v1/systemone', 'Bearer test-key', 'jev-latest',
                %w[material_concern_open validation_supported]]
    assert_equal expected, observed
    assert_state(payload.fetch('state'))
  end

  def assert_state(state) = [URL, HEAD, EVIDENCE].each { |part| assert_includes state, part }

  def invalid_answer(type:, noul:)
    OUTPUT.merge(answers: OUTPUT.fetch(:answers).merge(validation_supported: { type: type, noul: noul }))
  end

  def assert_result(result)
    assert_in_delta 0.91, result.fetch('answers').fetch('validation_supported')
    assert_equal 2500, result.fetch('input_tokens')
    assert_in_delta 0.000105, result.fetch('estimated_input_cost_usd'), 0.000000001
    assert_equal [URL, HEAD], result.values_at('pr_url', 'head')
    assert_equal Digest::SHA256.hexdigest(EVIDENCE), result.fetch('evidence_sha256')
  end

  def response(code, body) = Struct.new(:code, :body).new(code.to_s, JSON.generate(body))

  def analyzer(api_key:, client:, public_repository: ->(*) { true })
    ShakaJev::Analysis.new(api_key: api_key, client: client, public_repository: public_repository)
  end

  def target = { pr_url: URL, head: HEAD, evidence: 'Public' }
end

class JevHttpTransportTest < Minitest::Test
  def test_whole_request_has_a_deadline
    client = ->(*) { sleep 5 }
    analysis = ShakaJev::Analysis.new(api_key: 'test-key', client: client, public_repository: ->(*) { true },
                                      request_deadline_seconds: 0.05)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    error = assert_raises(ShakaJev::Error) do
      analysis.call(pr_url: JevAnalysisTest::URL, head: JevAnalysisTest::HEAD, evidence: 'Public')
    end
    assert_match(/Timeout::Error/, error.message)
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 1
  end

  def test_bad_json_and_timeout_have_clean_errors
    transport_failures.each do |client|
      analysis = ShakaJev::Analysis.new(api_key: 'test-key', client: client, public_repository: ->(*) { true })
      error = assert_raises(ShakaJev::Error) do
        analysis.call(pr_url: JevAnalysisTest::URL, head: JevAnalysisTest::HEAD, evidence: 'Public')
      end
      assert_match(/Jev request failed/, error.message)
    end
  end

  def test_default_transport_requires_tls_and_bounded_timeouts
    response = Struct.new(:code, :body).new('200', JSON.generate(JevAnalysisTest::OUTPUT))
    with_http_start(fake_transport(response)) do
      result = ShakaJev::Analysis.new(api_key: 'test-key', public_repository: ->(*) { true }).call(
        pr_url: JevAnalysisTest::URL, head: JevAnalysisTest::HEAD, evidence: 'Public'
      )
      assert_equal 'jev-1.13.0', result.fetch('model')
    end
  end

  private

  def transport_failures
    [->(*) { Struct.new(:code, :body).new('200', '<html>') },
     ->(*) { raise Net::ReadTimeout },
     ->(*) { raise Net::HTTPHeaderSyntaxError, 'invalid Content-Length' },
     ->(*) { raise Zlib::DataError, 'invalid compressed body' }]
  end

  def fake_transport(response)
    test = self
    http = Object.new
    http.define_singleton_method(:request) { |_| response }
    lambda do |host, port, **options, &block|
      test.assert_equal ['api.typesafe.ai', 443], [host, port]
      test.assert_equal({ use_ssl: true, open_timeout: 10, read_timeout: 30 }, options)
      block.call(http)
    end
  end

  def with_http_start(replacement)
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start, replacement)
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end
end

class JevDefaultVisibilityTest < Minitest::Test
  def test_default_analyzer_rejects_private_repository_before_sending
    Dir.mktmpdir do |dir|
      install_fake_gh(dir)
      with_path(dir) { assert_private_rejected }
    end
  end

  private

  def assert_private_rejected
    client = ->(*) { flunk 'must not send private evidence' }
    error = assert_raises(ShakaJev::Error) do
      ShakaJev::Analysis.new(api_key: 'test-key', client: client).call(
        pr_url: JevAnalysisTest::URL, head: JevAnalysisTest::HEAD, evidence: 'Private'
      )
    end
    assert_match(/verified public/, error.message)
  end

  def install_fake_gh(dir)
    gh = File.join(dir, 'gh')
    File.write(gh, "#!/bin/sh\nprintf '%s\\n' '{\"visibility\":\"PRIVATE\"}'\n")
    File.chmod(0o755, gh)
  end

  def with_path(dir)
    original = ENV.fetch('PATH')
    ENV['PATH'] = "#{dir}#{File::PATH_SEPARATOR}#{original}"
    yield
  ensure
    ENV['PATH'] = original
  end
end

class JevPublicGitHubRepositoryTest < Minitest::Test
  def test_stalled_github_lookup_fails_closed
    capture = ->(*) { raise Timeout::Error }
    refute ShakaJev::PublicGitHubRepository.call('shakacode', 'shaka', capture: capture)
  end

  def test_timed_out_subprocess_is_stopped
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    assert_raises(Timeout::Error) do
      ShakaJev::PublicGitHubRepository.capture_with_timeout(RbConfig.ruby, '-e', 'sleep 30', timeout: 0.05)
    end
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 10
  end

  def test_only_successful_public_metadata_is_accepted
    assert_visibility('PUBLIC', success: true, expected: true)
    assert_visibility('PRIVATE', success: true, expected: false)
    assert_visibility('PUBLIC', success: false, expected: false)
  end

  def test_non_object_metadata_fails_closed
    status = Struct.new(:success?).new(true)
    capture = ->(*) { ['null', status] }
    refute ShakaJev::PublicGitHubRepository.call('shakacode', 'shaka', capture: capture)
  end

  def test_missing_github_cli_fails_closed
    capture = ->(*) { raise Errno::ENOENT }
    refute ShakaJev::PublicGitHubRepository.call('shakacode', 'shaka', capture: capture)
  end

  def test_candidate_gh_is_skipped_and_type_safe_key_is_not_passed_to_github
    with_candidate_gh do |candidate_gh|
      observed = nil
      capture = lambda do |*args, **|
        observed = args
        [JSON.generate(visibility: 'PUBLIC'), Struct.new(:success?).new(true)]
      end
      assert ShakaJev::PublicGitHubRepository.call('shakacode', 'shaka', capture: capture)
      assert_safe_lookup(observed, candidate_gh)
    end
  end

  private

  def with_candidate_gh
    Dir.mktmpdir('jev-candidate-', Dir.pwd) do |dir|
      path = File.join(dir, 'gh')
      File.write(path, "#!/bin/sh\nexit 99\n")
      File.chmod(0o755, path)
      original = ENV.fetch('PATH')
      ENV['PATH'] = "#{dir}#{File::PATH_SEPARATOR}#{original}"
      yield path
    ensure
      ENV['PATH'] = original
    end
  end

  def assert_safe_lookup(observed, candidate_gh)
    refute_equal candidate_gh, observed[1]
    assert_nil observed.first.fetch('TYPESAFE_API_KEY')
    refute_includes observed.first.fetch('PATH').split(File::PATH_SEPARATOR), File.dirname(candidate_gh)
  end

  def assert_visibility(visibility, success:, expected:)
    status = Struct.new(:success?).new(success)
    command = nil
    capture = lambda do |*args, **options|
      command = [args, options]
      [JSON.generate(visibility: visibility), status]
    end
    assert_equal expected, ShakaJev::PublicGitHubRepository.call('shakacode', 'shaka', capture: capture)
    assert_capture_call(command.first)
    assert_equal File::NULL, command.last.fetch(:err)
  end

  def assert_capture_call(args)
    assert_equal 'github.com', args.first.fetch('GH_HOST')
    assert_nil args.first.fetch('TYPESAFE_API_KEY')
    assert_equal ['repo', 'view', 'shakacode/shaka', '--json', 'visibility'], args.drop(2)
    assert_equal 'gh', File.basename(args[1])
    assert_path_exists args[1]
  end
end
