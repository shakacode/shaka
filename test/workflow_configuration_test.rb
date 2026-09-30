# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/workflow_configuration'

class WorkflowConfigurationTest < Minitest::Test
  SHA = 'a' * 40
  WORKFLOW = '.github/workflows/ci.yml'
  SECRET_VALUE = 'SUPER-SECRET-VALUE'

  def test_references_collect_secret_and_variable_names_except_the_token
    text = <<~YAML
      env:
        KEY: ${{ secrets.AWS_KEY }}
        REGION: ${{ vars.REGION }}
        TOKEN: ${{ secrets.GITHUB_TOKEN }}
        NAMED: ${{ vars.GITHUB_TOKEN }}
      # notsecrets.NOPE and secrets.AWS_KEY again
    YAML

    assert_equal({ 'secrets' => ['AWS_KEY'], 'vars' => %w[GITHUB_TOKEN REGION] },
                 Shaka::WorkflowConfiguration.references(text))
  end

  def test_a_missing_repo_secret_is_reported_and_variable_values_are_dropped
    result = check(files: [file_row], contents: { WORKFLOW => "run: ${{ secrets.DEPLOY_KEY }}\n" },
                   repo: user_repo, secrets: [], variables: [{ 'name' => 'UNUSED', 'value' => SECRET_VALUE }])

    assert_equal ['secrets.DEPLOY_KEY'], result['missing']
    assert_equal 'missing', result['status']
    refute_includes JSON.generate(result), SECRET_VALUE
    refute_includes @github.paths.join("\n"), 'actions/variables'
  end

  def test_a_name_present_on_the_repo_or_a_visible_org_secret_is_clear
    text = "${{ secrets.REPO_KEY }}\n${{ secrets.ORG_KEY }}\n${{ vars.REGION }}\n"
    result = check(files: [file_row], contents: { WORKFLOW => text }, repo: org_repo,
                   secrets: [{ 'name' => 'REPO_KEY' }], variables: [{ 'name' => 'REGION', 'value' => SECRET_VALUE }],
                   org_secrets: [{ 'name' => 'ORG_KEY' }])

    assert_equal 'clear', result['status']
    refute_includes JSON.generate(result), SECRET_VALUE
  end

  CALLER_WORKFLOW = <<~YAML
    on:
      workflow_call:
        secrets:
          token:
            required: true
    jobs:
      call:
        steps:
          - run: echo ${{ secrets.token }}
  YAML
  ENVIRONMENT = <<~YAML.chomp
    jobs:
      deploy:
        environment: production
        steps:
          - run: echo ${{ secrets.DEPLOY_KEY }}
  YAML

  def test_a_caller_supplied_workflow_secret_is_not_a_repository_secret
    result = check(files: [file_row], contents: { WORKFLOW => CALLER_WORKFLOW }, repo: user_repo, secrets: [])

    assert_equal 'clear', result['status']
  end

  def test_an_environment_secret_is_not_missing_when_that_environment_has_it
    result = check(files: [file_row], contents: { WORKFLOW => ENVIRONMENT }, repo: user_repo, secrets: [],
                   environment_secrets: { 'production' => [{ 'name' => 'DEPLOY_KEY' }] })

    assert_equal 'clear', result['status']
  end

  def test_a_404_on_the_secret_list_is_unverified
    result = check(files: [file_row], contents: { WORKFLOW => '${{ secrets.DEPLOY_KEY }}' },
                   repo: user_repo, secrets: :missing)

    assert_equal 'unverified', result['status']
    assert_empty result['missing']
  end

  def test_http_403_on_secret_names_is_unverified_instead_of_missing
    result = check(files: [file_row], contents: { WORKFLOW => '${{ secrets.DEPLOY_KEY }}' },
                   repo: user_repo, secrets: :denied)

    assert_equal 'unverified', result['status']
    assert_empty result['missing']
    assert_equal ['secrets.DEPLOY_KEY'], result['unverified']
  end

  def test_unchanged_workflow_paths_and_removed_files_are_ignored
    files = [{ 'filename' => 'README.md', 'status' => 'modified' }, { 'filename' => WORKFLOW, 'status' => 'removed' }]
    result = check(files:)

    assert_equal 'clear', result['status']
    refute(@github.paths.any? { |path| path.include?('contents') })
  end

  private

  def check(**options)
    @github = RouteGitHub.new(options)
    Shaka::WorkflowConfiguration.new(@github).call(pull)
  end

  def pull = { 'headRefOid' => SHA, 'headRepository' => { 'nameWithOwner' => 'owner/repo' } }
  def file_row = { 'filename' => WORKFLOW, 'status' => 'modified' }
  def user_repo = { 'private' => false, 'owner' => { 'type' => 'User' } }
  def org_repo = { 'private' => false, 'owner' => { 'type' => 'Organization' } }
end

# Serves the name lists a workflow check reads. Secret and variable values stay in the route table.
class RouteGitHub
  PAGE = 'per_page=100&page=1'

  attr_reader :paths

  def initialize(routes)
    @contents = routes.fetch(:contents, {})
    @paths = []
    @routes = {}
    remember_routes(routes)
  end

  def remember_routes(routes)
    remember("repos/owner/repo/pulls/42/files?#{PAGE}", routes[:files])
    remember('repos/owner/repo', routes[:repo])
    remember_name_lists(routes)
  end

  def remember_name_lists(routes)
    remember_list("repos/owner/repo/actions/secrets?#{PAGE}", 'secrets', routes[:secrets])
    remember_list("repos/owner/repo/actions/variables?#{PAGE}", 'variables', routes[:variables])
    remember_list("repos/owner/repo/actions/organization-secrets?#{PAGE}", 'secrets', routes[:org_secrets])
    Array(routes[:environment_secrets]).each do |name, rows|
      remember_list("repos/owner/repo/environments/#{name}/secrets?#{PAGE}", 'secrets', rows)
    end
  end

  def repository = 'owner/repo'
  def number = 42
  def api(path, **) = body(path)
  def api_list(path) = body(path)

  private

  def remember(path, value)
    return if value.nil?

    @routes[path] = value
  end

  def remember_list(path, key, rows)
    return if rows.nil?

    @routes[path] = [key, rows]
  end

  def body(path)
    @paths << path
    return list(@routes[path]) if @routes[path].is_a?(Array) && @routes[path].first.is_a?(String)
    return @routes.fetch(path) if @routes.key?(path)
    return encoded(@contents.fetch(WorkflowConfigurationTest::WORKFLOW)) if path.include?('/contents/')

    raise "unexpected #{path}"
  end

  def list(pair)
    key, rows = pair
    raise Shaka::Error.new('denied', http_status: 403) if rows == :denied
    raise Shaka::Error.new('missing', http_status: 404) if rows == :missing

    { key => rows }
  end

  def encoded(text) = { 'encoding' => 'base64', 'content' => [text].pack('m') }
end
