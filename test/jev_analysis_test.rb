# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'rbconfig'
require_relative '../skills/shaka-jev/lib/shaka_jev/analysis'

class JevAnalysisTest < Minitest::Test
  HEAD = 'a' * 40
  URL = 'https://github.com/shakacode/shaka/pull/302'
  OUTPUT = {
    model: 'jev-1.13.0',
    answers: {
      validation_supported: { type: 'noul', noul: 0.91 },
      material_concern_open: { type: 'noul', noul: 0.13 }
    },
    usage: { input_tokens: 2500, output_tokens: 25 }
  }.freeze

  def test_sends_one_request_with_fixed_questions_and_reports_usage
    sent = nil
    client = lambda do |uri, request|
      sent = [uri, request]
      response(200, OUTPUT)
    end
    result = analyzer(api_key: 'test-key', client: client).call(
      pr_url: URL, head: HEAD, evidence: 'Public validation and review evidence.'
    )

    assert_request(sent)
    assert_result(result)
  end

  def test_rejects_missing_key_before_sending
    client = ->(*) { flunk 'must not send' }
    assert_raises(ShakaJev::Error) do
      analyzer(api_key: '', client: client).call(pr_url: URL, head: HEAD, evidence: 'Public')
    end
  end

  def test_rejects_malformed_model_output_without_a_verdict
    malformed = OUTPUT.merge(answers: OUTPUT.fetch(:answers).merge(validation_supported: { type: 'noul', noul: 1.5 }))
    client = ->(*) { response(200, malformed) }
    error = assert_raises(ShakaJev::Error) { analyzer(api_key: 'test-key', client: client).call(**target) }
    assert_match(/Invalid Jev answer/, error.message)
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
    invalid = [{ pr_url: 'https://github.com/shakacode/shaka/issues/302' },
               { head: 'abc123' }, { evidence: '   ' }, { evidence: 'x' * 65_537 }]
    invalid.each do |change|
      assert_raises(ShakaJev::Error) do
        analyzer(api_key: 'test-key', client: client).call(**target, **change)
      end
    end
  end

  def test_command_reports_missing_options_and_unreadable_file_cleanly
    command = [RbConfig.ruby, File.expand_path('../skills/shaka-jev/scripts/analyze', __dir__),
               '--pr-url', URL, '--head', HEAD]
    missing, missing_status = Open3.capture2e(*command)
    unreadable, unreadable_status = Open3.capture2e(*command, '--evidence', '/no/such/evidence-file')

    refute_predicate missing_status, :success?
    refute_predicate unreadable_status, :success?
    assert_match(/shaka-jev:/, missing)
    assert_match(/shaka-jev:/, unreadable)
    refute_match(/in `/, unreadable)
  end

  private

  def assert_request(sent)
    payload = JSON.parse(sent.last.body)
    observed = [sent.first.to_s, sent.last['Authorization'], payload.fetch('model'),
                payload.fetch('questions').keys.sort]
    expected = ['https://api.typesafe.ai/v1/systemone', 'Bearer test-key', 'jev-latest',
                %w[material_concern_open validation_supported]]
    assert_equal expected, observed
    assert_includes payload.fetch('state'), HEAD
  end

  def assert_result(result)
    assert_in_delta 0.91, result.fetch('answers').fetch('validation_supported')
    assert_equal 2500, result.fetch('input_tokens')
    assert_in_delta 0.000105, result.fetch('estimated_input_cost_usd'), 0.000000001
    assert_match(/\A[0-9a-f]{64}\z/, result.fetch('evidence_sha256'))
  end

  def response(code, body)
    Struct.new(:code, :body).new(code.to_s, JSON.generate(body))
  end

  def analyzer(api_key:, client:, public_repository: ->(*) { true })
    ShakaJev::Analysis.new(api_key: api_key, client: client, public_repository: public_repository)
  end

  def target = { pr_url: URL, head: HEAD, evidence: 'Public' }
end

class JevPublicGitHubRepositoryTest < Minitest::Test
  def test_only_successful_public_metadata_is_accepted
    cases = [[{ visibility: 'PUBLIC' }, true, true], [{ visibility: 'PRIVATE' }, true, false],
             [{ visibility: 'PUBLIC' }, false, false]]
    cases.each do |metadata, success, expected|
      status = Struct.new(:success?).new(success)
      capture = ->(*) { [JSON.generate(metadata), status] }
      assert_equal expected, ShakaJev::PublicGitHubRepository.call('shakacode', 'shaka', capture: capture)
    end
  end

  def test_missing_github_cli_fails_closed
    capture = ->(*) { raise Errno::ENOENT }
    refute ShakaJev::PublicGitHubRepository.call('shakacode', 'shaka', capture: capture)
  end
end
