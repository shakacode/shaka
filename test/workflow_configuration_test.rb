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
    result = check(files: [file_row], contents: { WORKFLOW => text }, repo: org_repo(private: false),
                   secrets: [{ 'name' => 'REPO_KEY' }], variables: [{ 'name' => 'REGION', 'value' => SECRET_VALUE }],
                   org_secrets: [{ 'name' => 'ORG_KEY', 'visibility' => 'all' }])

    assert_equal 'clear', result['status']
    refute_includes JSON.generate(result), SECRET_VALUE
  end

  def test_a_selected_org_secret_visible_to_the_repository_is_clear
    result = check(files: [file_row], contents: { WORKFLOW => '${{ secrets.CHOSEN }}' },
                   repo: org_repo(private: false), secrets: [],
                   org_secrets: [{ 'name' => 'CHOSEN', 'visibility' => 'selected' }],
                   selected: { 'CHOSEN' => ['owner/repo'] })

    assert_equal 'clear', result['status']
  end

  def test_a_private_org_secret_is_missing_from_a_public_repository
    result = check(files: [file_row], contents: { WORKFLOW => '${{ secrets.CHOSEN }}' },
                   repo: org_repo(private: false), secrets: [],
                   org_secrets: [{ 'name' => 'CHOSEN', 'visibility' => 'private' }])

    assert_equal ['secrets.CHOSEN'], result['missing']
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
  def org_repo(private:) = { 'private' => private, 'owner' => { 'type' => 'Organization' } }
end

# Serves the name lists a workflow check reads. Secret and variable values stay in the route table.
class RouteGitHub
  PAGE = 'per_page=100&page=1'

  attr_reader :paths

  def initialize(routes)
    @contents = routes.fetch(:contents, {})
    @selected = routes.fetch(:selected, {})
    @paths = []
    @routes = {}
    remember("repos/owner/repo/pulls/42/files?#{PAGE}", routes[:files])
    remember('repos/owner/repo', routes[:repo])
    remember_list("repos/owner/repo/actions/secrets?#{PAGE}", 'secrets', routes[:secrets])
    remember_list("repos/owner/repo/actions/variables?#{PAGE}", 'variables', routes[:variables])
    remember_list("orgs/owner/actions/secrets?#{PAGE}", 'secrets', routes[:org_secrets])
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
    return selected(path) if path.include?('/repositories?')

    raise "unexpected #{path}"
  end

  def list(pair)
    key, rows = pair
    raise Shaka::Error.new('denied', http_status: 403) if rows == :denied

    { key => rows }
  end

  def selected(path)
    name = path[%r{secrets/([^/]+)/repositories}, 1]
    { 'repositories' => @selected.fetch(name).map { |full_name| { 'full_name' => full_name } } }
  end

  def encoded(text) = { 'encoding' => 'base64', 'content' => [text].pack('m') }
end
