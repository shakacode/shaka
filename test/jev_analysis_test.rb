# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
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
      pr_url: URL, head: HEAD, evidence: 'Public validation and review evidence.'
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
    malformed = [OUTPUT.merge(model: ''), OUTPUT.merge(usage: { input_tokens: -1 }), [],
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
    invalid = [{ pr_url: 'https://github.com/shakacode/shaka/issues/302' },
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

  def assert_state(state)
    [URL, HEAD, 'Public validation and review evidence.'].each { |part| assert_includes state, part }
  end

  def invalid_answer(type:, noul:)
    OUTPUT.merge(answers: OUTPUT.fetch(:answers).merge(validation_supported: { type: type, noul: noul }))
  end

  def assert_result(result)
    assert_in_delta 0.91, result.fetch('answers').fetch('validation_supported')
    assert_equal 2500, result.fetch('input_tokens')
    assert_in_delta 0.000105, result.fetch('estimated_input_cost_usd'), 0.000000001
    assert_match(/\A[0-9a-f]{64}\z/, result.fetch('evidence_sha256'))
  end

  def response(code, body) = Struct.new(:code, :body).new(code.to_s, JSON.generate(body))

  def analyzer(api_key:, client:, public_repository: ->(*) { true })
    ShakaJev::Analysis.new(api_key: api_key, client: client, public_repository: public_repository)
  end

  def target = { pr_url: URL, head: HEAD, evidence: 'Public' }
end

class JevPublicGitHubRepositoryTest < Minitest::Test
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

  private

  def assert_visibility(visibility, success:, expected:)
    status = Struct.new(:success?).new(success)
    command = nil
    capture = lambda do |*args, **options|
      command = [args, options]
      [JSON.generate(visibility: visibility), status]
    end
    assert_equal expected, ShakaJev::PublicGitHubRepository.call('shakacode', 'shaka', capture: capture)
    assert_equal [{ 'GH_HOST' => 'github.com' }, 'gh', 'repo', 'view', 'shakacode/shaka', '--json',
                  'visibility'], command.first
    assert_equal File::NULL, command.last.fetch(:err)
  end
end
