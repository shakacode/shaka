# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/gitlab'

module GitLabTransportHelper
  STATUS = Struct.new(:exitstatus)

  def client(*responses)
    @calls = []
    runner = lambda do |argv, stdin_data:|
      @calls << [argv, stdin_data]
      responses.shift || raise('Unexpected GitLab request')
    end
    Shaka::GitLab.new(host: 'gitlab.example', project: 'group/sub/repo', runner:)
  end

  def response(value, code: 200, exitstatus: 0, next_page: nil)
    pagination = "X-Next-Page: #{next_page}\r\n" unless next_page.nil?
    ["HTTP/2.0 #{code} Status\r\nContent-Type: application/json\r\n#{pagination}\r\n#{JSON.generate(value)}",
     'private stderr token must not be disclosed', STATUS.new(exitstatus)]
  end
end

class GitLabTransportTest < Minitest::Test
  include GitLabTransportHelper

  def test_invalid_host_cannot_redirect_authenticated_requests
    ['https://gitlab.example', 'user:secret@gitlab.example', '--help', "gitlab.example\nother",
     'gitlab.example/path', 'gitlab.example:0', 'gitlab.example:65536', nil].each do |host|
      assert_raises(Shaka::Error) { Shaka::GitLab.new(host:, project: 'group/repo') }
    end
  end

  def test_invalid_namespace_cannot_change_project_or_endpoint
    ['repo', 'group//repo', 'group/../repo', 'group/./repo', 'group/repo/', '/group/repo',
     'group/repo?private=1', 'group%2Frepo/project', "group/repo\n", nil].each do |project|
      assert_raises(Shaka::Error) { Shaka::GitLab.new(host: 'gitlab.example', project:) }
    end
  end

  def test_endpoint_cannot_override_authenticated_host_or_pass_an_option
    ['https://other.example/api/v4/projects/7', '/projects/7', '--help', 'projects//7',
     'projects/../7', 'projects/7#fragment', "projects/7\n", 'projects/7?access_token=secret'].each do |path|
      instance = client
      assert_raises(Shaka::Error) { instance.api(path) }
      assert_empty @calls
    end
  end

  def test_encoded_full_namespace_is_a_single_endpoint_segment
    assert_equal({ 'id' => 7 }, client(response({ 'id' => 7 })).api('projects/group%2Fsub%2Frepo'))
    assert_equal 'projects/group%2Fsub%2Frepo', @calls.first[0][4]
  end

  def test_http_failures_preserve_status_without_disclosing_response_or_stderr
    [401, 403, 404, 429, 500].each do |code|
      error = assert_raises(Shaka::Error) do
        client(response({ 'message' => 'private response token' }, code:, exitstatus: 1)).api('projects/7')
      end
      assert_equal code, error.http_status
      refute_match(/private|token|stderr/, error.message)
    end
  end

  def test_non_success_http_status_fails_even_if_cli_exits_successfully
    error = assert_raises(Shaka::Error) do
      client(response({ 'message' => 'not authorized' }, code: 403)).api('projects/7')
    end
    assert_equal 403, error.http_status
  end

  def test_nonzero_cli_exit_does_not_accept_an_apparent_success_response
    assert_raises(Shaka::Error) do
      client(response({ 'id' => 7 }, exitstatus: 1)).api('projects/7')
    end
  end

  def test_missing_response_headers_do_not_turn_stderr_into_capability_evidence
    error = assert_raises(Shaka::Error) do
      client(['', 'private stderr (HTTP 404)', STATUS.new(1)]).api('projects/7')
    end
    assert_nil error.http_status
    refute_match(/private|stderr/, error.message)
  end

  def test_signaled_cli_is_a_domain_failure_even_with_success_headers
    error = assert_raises(Shaka::Error) do
      client(response({ 'id' => 7 }, exitstatus: nil)).api('projects/7')
    end
    assert_match(/failed/, error.message)
  end

  def test_empty_success_requires_explicit_no_content_expectation
    empty = ["HTTP/2.0 204 No Content\r\n\r\n", '', STATUS.new(0)]
    assert_nil client(empty).api('projects/7/repository/branches/topic', method: 'DELETE', expected: NilClass)
    assert_raises(Shaka::Error) { client(empty).api('projects/7') }
  end

  def test_invalid_json_utf8_or_missing_http_envelope_is_a_domain_error
    ["HTTP/2.0 200 OK\r\n\r\nnot json", "HTTP/2.0 200 OK\r\n\r\n{\"name\":\"\xff\"}".b,
     '{}', "HTTP/2.0 200 OK\r\n\r\n", nil].each do |output|
      assert_raises(Shaka::Error) { client([output, '', STATUS.new(0)]).api('projects/7') }
    end
  end

  def test_unexpected_json_shapes_are_not_project_metadata
    [[], nil, 'text', 7].each do |value|
      assert_raises(Shaka::Error) { client(response(value)).api('projects/7') }
    end
  end

  def test_missing_cli_gives_an_actionable_domain_error
    runner = ->(*) { raise Errno::ENOENT }
    error = assert_raises(Shaka::Error) do
      Shaka::GitLab.new(host: 'gitlab.example', project: 'group/repo', runner:).api('projects/7')
    end
    assert_match(/glab/, error.message)
    assert_match(/install|authenticate/, error.message)
  end
end

class GitLabPaginationTest < Minitest::Test
  include GitLabTransportHelper

  def test_short_page_with_next_page_header_does_not_truncate_records
    instance = client(response([{ 'id' => 1 }], next_page: '2'), response([{ 'id' => 2 }], next_page: ''))
    assert_equal [{ 'id' => 1 }, { 'id' => 2 }], instance.api_list('projects/7/members')
    paths = @calls.map { |argv, _input| argv[4] }
    assert_equal ['projects/7/members?per_page=100&page=1', 'projects/7/members?per_page=100&page=2'], paths
  end

  def test_malformed_or_nonadvancing_next_page_header_is_incomplete_evidence
    %w[1 invalid].each do |next_page|
      assert_raises(Shaka::Error) do
        client(response([{ 'id' => 1 }], next_page:)).api_list('projects/7/members')
      end
      assert_equal 1, @calls.length
    end
  end

  def test_list_preserves_later_page_records
    first = Array.new(100) { |index| { 'id' => index + 1 } }
    result = client(response(first), response([{ 'id' => 101, 'access_level' => 40 }])).api_list('projects/7/members')
    paths = @calls.map { |argv, _input| argv[4] }
    assert_equal 101, result.length
    assert_equal({ 'id' => 101, 'access_level' => 40 }, result.last)
    assert_equal ['projects/7/members?per_page=100&page=1', 'projects/7/members?per_page=100&page=2'],
                 paths
  end

  def test_full_final_page_requires_an_additional_empty_page
    page = Array.new(100) { |index| { 'id' => index + 1 } }
    assert_equal 100, client(response(page), response([])).api_list('projects/7/members').length
    assert_equal 2, @calls.length
  end

  def test_later_page_failure_does_not_return_partial_actor_evidence
    page = Array.new(100) { |index| { 'id' => index + 1 } }
    error = assert_raises(Shaka::Error) do
      client(response(page), response({ 'message' => 'private token' }, code: 403, exitstatus: 1))
        .api_list('projects/7/members')
    end
    assert_equal 403, error.http_status
    assert_equal 2, @calls.length
  end

  def test_list_rejects_malformed_records_instead_of_screening_partial_evidence
    [nil, 'unreadable actor', 3, []].each do |record|
      assert_raises(Shaka::Error) do
        client(response([{ 'id' => 1 }, record])).api_list('projects/7/members')
      end
    end
  end

  def test_list_limit_fails_closed_instead_of_silently_truncating
    calls = 0
    page = Array.new(100) { |index| { 'id' => index + 1 } }
    runner = lambda do |*|
      calls += 1
      response(page)
    end
    assert_raises(Shaka::Error) do
      Shaka::GitLab.new(host: 'gitlab.example', project: 'group/repo', runner:).api_list('projects/7/members')
    end
    assert_equal 100, calls
  end
end

class GitLabQueryFiltersTest < Minitest::Test
  include GitLabTransportHelper

  def test_ambiguous_or_composite_filters_cannot_return_a_successful_incomplete_list
    [{ iids: [1, 2] }, { filter: { id: 1 } }, { state: nil }, { 'state' => 'opened', state: 'closed' }].each do |fields|
      instance = client(response([]))
      assert_raises(Shaka::Error) { instance.api_list('projects/7/merge_requests', fields:) }
      assert_empty @calls
    end
  end

  def test_get_query_fields_reject_composites_before_requesting
    [{ iids: [1, 2] }, { filter: { id: 1 } }].each do |fields|
      instance = client(response({}))
      assert_raises(Shaka::Error) { instance.api('projects/7/merge_requests', fields:) }
      assert_empty @calls
    end
  end

  def test_get_fields_are_encoded_as_query_parameters_instead_of_a_request_body
    fields = { ref: 'feature+policy/日本語 & config' }
    instance = client(response({ 'file_path' => 'policy.yml' }))
    instance.api('projects/7/repository/files/policy.yml', fields:)
    argv, input = @calls.first
    assert_equal "projects/7/repository/files/policy.yml?#{URI.encode_www_form(fields)}", argv[4]
    assert_equal 'GET', argv[6]
    assert_equal({}, JSON.parse(input))
    assert_equal({ ref: 'feature+policy/日本語 & config' }, fields)
  end

  def test_write_fields_remain_json_payloads
    fields = { body: 'Keep + and & in the note.' }
    instance = client(response({ 'id' => 41 }))
    instance.api('projects/7/notes', method: 'POST', fields:)
    argv, input = @calls.first
    assert_equal 'projects/7/notes', argv[4]
    assert_equal 'POST', argv[6]
    assert_equal({ 'body' => fields[:body] }, JSON.parse(input))
  end

  def test_filters_are_preserved_and_encoded_on_every_native_list_page
    fields = { state: 'all', source_branch: 'feature+config/path & other' }
    instance = client(response([{ 'id' => 1 }], next_page: '2'), response([{ 'id' => 2 }], next_page: ''))
    assert_equal [{ 'id' => 1 }, { 'id' => 2 }], instance.api_list('projects/7/merge_requests', fields:)
    prefix = "projects/7/merge_requests?#{URI.encode_www_form(fields)}&per_page=100&page="
    paths = @calls.map { |argv, _input| argv[4] }
    assert_equal ["#{prefix}1", "#{prefix}2"], paths
    assert_equal({ state: 'all', source_branch: 'feature+config/path & other' }, fields)
  end

  def test_list_filters_cannot_override_reserved_pagination_fields
    [{ page: 5 }, { 'page' => 5 }, { per_page: 1 }, { 'per_page' => 1 }, nil, []].each do |fields|
      instance = client
      assert_raises(Shaka::Error) { instance.api_list('projects/7/merge_requests', fields:) }
      assert_empty @calls
    end
  end

  def test_later_filtered_page_failure_returns_no_partial_list
    instance = client(response([{ 'id' => 1 }], next_page: '2'), response({}, code: 403, exitstatus: 1))
    error = assert_raises(Shaka::Error) { instance.api_list('projects/7/merge_requests', fields: { state: 'all' }) }
    assert_equal 403, error.http_status
    assert_equal 2, @calls.length
  end
end
