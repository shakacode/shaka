# frozen_string_literal: true

require 'json'
require 'shaka/branch_head/handover_command'
require 'shaka/branch_head/command'
require_relative 'branch_head_fixture'

# A PR's comments held in memory, answering the gh calls Ownership and `branch --pr` make, so release and pickup
# run against real Git checkouts without the network. `as` names the account the next comments come from.
module BranchHeadOwnershipFixture
  include BranchHeadFixture

  REQUEST = { repository: 'base/repo', number: '7' }.freeze
  IDENTITY = { 'agent' => 'Claude', 'provider' => 'Anthropic', 'model' => 'test-model', 'effort' => 'low' }.freeze

  # Fake GitHub: comments, account permissions, and a hook that runs once before the next comment is stored.
  class FakeGitHub
    attr_accessor :login, :before_post, :after_post, :pull_head, :git
    attr_reader :comments

    def initialize(permissions)
      @permissions = permissions
      @comments = []
      @login = permissions.keys.first
    end

    # Git runs for real; only gh is answered here.
    def call(argv, chdir = nil)
      return git.call(argv, chdir) unless argv.first == 'gh'

      return [JSON.generate(pull), '', true] if argv[1..2] == %w[pr view]

      path = argv.find { |part| part.start_with?('repos/') }
      method = argv[argv.index('-X') + 1] if argv.include?('-X')
      answer(path, method, argv)
    end

    private

    def answer(path, method, argv)
      case [path, method]
      in [%r{/permission\z}, nil] then permission(path.split('/')[-2])
      in [_, 'POST'] then created(argv)
      in [_, 'PATCH'] then edited(path.split('/').last.to_i, argv)
      else [listing, '', true]
      end
    end

    def pull
      { 'url' => 'https://push.example.com/base/repo/pull/7', 'state' => 'OPEN', 'headRefName' => BranchHeadFixture::BRANCH,
        'headRefOid' => pull_head, 'headRepository' => { 'name' => 'repo' },
        'headRepositoryOwner' => { 'login' => 'base' },
        'statusCheckRollup' => [{ 'conclusion' => 'SUCCESS' }, { 'conclusion' => 'FAILURE' }, { 'state' => 'PENDING' }],
        'body' => '', 'author' => { 'login' => 'owner' } }
    end

    def permission(login)
      role = @permissions[login]
      return ['', 'gh: Not Found (HTTP 404)', false] unless role

      ["#{role == 'maintain' ? 'write' : role} #{role}\n", '', true]
    end

    def created(argv)
      author = login
      hook = before_post
      self.before_post = nil
      hook&.call
      comment = { 'id' => @comments.size + 1, 'login' => author, 'body' => body(argv) }
      @comments << comment
      after_post.tap { self.after_post = nil }&.call
      [JSON.generate(rest(comment)), '', true]
    end

    def edited(id, argv)
      comment = @comments.find { |each| each['id'] == id }
      comment['body'] = body(argv)
      [JSON.generate(rest(comment)), '', true]
    end

    def body(argv) = argv[argv.index('-f') + 1].delete_prefix('body=')

    def rest(comment) = comment.merge('html_url' => "https://push.example.com/c/#{comment['id']}")

    def listing
      @comments.select { |comment| comment['body'].include?('<!-- shaka:ownership ') }.map do |comment|
        JSON.generate('id' => comment['id'], 'url' => rest(comment)['html_url'], 'body' => comment['body'],
                      'login' => comment['login'], 'type' => 'User')
      end.join("\n")
    end
  end

  def setup
    super
    @github = FakeGitHub.new('owner' => 'write', 'teammate' => 'write', 'other' => 'write', 'maint' => 'maintain',
                             'visitor' => 'read')
    stub_gh(@github)
  end

  def teardown
    restore_gh
    super
  end

  private

  def ownership = Shaka::BranchHead::Ownership.new(REQUEST, 'owner')

  def content(tag) = { 'identity' => IDENTITY, 'owner_tag' => tag, 'remaining' => 'Write the docs' }

  def handover(root, tag)
    head = Shaka::BranchHead.new(root:)
    Shaka::BranchHead::Handover.new(head, ownership, content(tag), root)
  end

  def pull_for(sha) = { 'branch' => BRANCH, 'head' => sha, 'checks' => [], 'body' => '' }

  def release(root, tag, sha, as: 'owner', maintainer: false)
    @github.login = as
    handover(root, tag).release(pull_for(sha), maintainer:)
  end

  def last_comment = @github.comments.last['body']

  def remote_head
    git(@dir, '--git-dir', @origin, 'rev-parse', '--verify', '--quiet', BRANCH).strip
  rescue RuntimeError
    nil
  end

  def paused(root) = Shaka::BranchHead::HandoverCommand.status(root, ownership)['state']

  def assert_paused(state, root)
    assert_equal(state || 'holds', paused(root))
  end

  # The task pushed and released, so the PR is open for pickup.
  def released_task
    sha = push_task('first')
    release(@task, 'origtag', sha)
    sha
  end

  def pickup(root, tag, as: 'teammate', override: false)
    @github.login = as
    handover(root, tag).pickup(pull_for(remote_head), override:)
  end

  def teammate_clone
    git(@dir, 'clone', '--quiet', '--branch', BRANCH, @origin, @teammate) unless Dir.exist?(@teammate)
    @teammate
  end

  def stub_gh(fake)
    @original_new = Shaka::Doctor::BoundedCommand.method(:new)
    fake.git = @original_new.call(timeout: 120)
    Shaka::Doctor::BoundedCommand.define_singleton_method(:new) { |**| fake }
  end

  def restore_gh = Shaka::Doctor::BoundedCommand.define_singleton_method(:new, @original_new)
end
