# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'json'

# Runs the shaka command against immutable policy with a fake gh on PATH.
module CliMergeFixture
  include RepositoryConfigTestHelpers

  COMMAND = SHAKA_COMMAND
  HEAD = 'a' * 40
  # A person's confirmation of the head, which passes merge.auto_merge_max_risk for tests of other gates; the risk
  # gate itself reads a checkpoint rating these fakes do not publish.
  CONFIRMED = ['--limits-confirmed-head', HEAD].freeze
  FAKE_GH = <<~'RUBY_SCRIPT'
    #!/usr/bin/env ruby
    require 'json'
    head = 'a' * 40
    pull = { 'id' => 'PR_123', 'headRefOid' => head, 'baseRefName' => 'main',
             'state' => 'OPEN', 'isDraft' => false, 'viewerCanMergeAsAdmin' => true,
             'isMergeQueueEnabled' => false, 'isInMergeQueue' => false,
             'mergeQueueEntry' => nil, 'autoMergeRequest' => nil,
             'mergeStateStatus' => 'CLEAN', 'reviewDecision' => 'APPROVED',
             'changedFiles' => 1, 'additions' => 1, 'deletions' => 0,
             'commits' => { 'totalCount' => 1 } }
    labels = ENV.fetch('PR_LABELS', '').split(',').map { |name| { 'name' => name } }
    pull['labels'] = { 'totalCount' => labels.length, 'nodes' => labels }
    if ARGV[0, 2] == ['api', 'graphql']
      request = JSON.parse($stdin.read)
      if request.fetch('query').include?('mergePullRequest')
        File.write(ENV.fetch('MUTATION_FILE'), JSON.generate(request))
        result = { 'mergePullRequest' => { 'pullRequest' => pull.merge('state' => 'MERGED', 'merged' => true) } }
      else
        result = { 'repository' => { 'pullRequest' => pull } }
      end
      puts JSON.generate('data' => result)
    elsif ARGV[0, 2] == ['pr', 'checks'] && ENV['RATE_LIMITED']
      warn 'gh: API rate limit exceeded (HTTP 403)'
      exit 1
    elsif ARGV[0, 2] == ['pr', 'checks'] && ENV['NO_REQUIRED_CHECKS'] && ARGV.include?('--required')
      warn "no required checks reported on the 'main' branch"
      exit 1
    elsif ARGV[0] == 'api' && ARGV[1].start_with?('repos/owner/repo/rules/branches/main')
      puts '[]'
    elsif ARGV[0, 2] == ['pr', 'checks']
      puts JSON.generate([{ 'name' => 'checks', 'state' => 'SUCCESS', 'bucket' => 'pass' }])
    elsif ARGV[0, 2] == ['api', 'user']
      puts JSON.generate('login' => 'agent')
    elsif ARGV[0] == 'api' && ARGV[1].start_with?('repos/owner/repo/pulls/1/reviews?')
      puts(ARGV[1].end_with?('page=1') ? ENV.fetch('PR_REVIEWS', '[]') : '[]')
    elsif ARGV[0] == 'api' && ARGV[1].start_with?('repos/owner/repo/issues/1/comments?')
      puts(ARGV[1].end_with?('page=1') ? ENV.fetch('PR_COMMENTS', '[]') : '[]')
    elsif ARGV[0, 2] == ['api', 'repos/owner/repo/pulls/1/reviews/17']
      body = "🤖 Codex · OpenAI · model · high\n\n# Code Walkthrough\n\nTour.\n\n" \
             "_Walkthrough for commit `#{head}`. This is a COMMENT, not an approval._"
      puts JSON.generate('id' => 17, 'commit_id' => head, 'state' => 'COMMENTED', 'body' => body,
                         'user' => { 'login' => 'agent' })
    elsif ARGV[0] == 'api' && ARGV[1].start_with?('repos/owner/repo/pulls/1/commits?')
      puts JSON.generate([{ 'sha' => head, 'commit' => { 'message' => 'Fix' } }])
    else
      warn "unexpected gh #{ARGV.join(' ')}"
      exit 2
    end
  RUBY_SCRIPT

  private

  def with_merge_repository(merge = merge_policy, **settings)
    with_repository({ 'merge' => merge,
                      'review' => review_policy('required' => 'none').except('ci_review_jobs'),
                      'checkpoint' => { 'enabled' => false } }.merge(settings.transform_keys(&:to_s))) do |root|
      commit_repository(root)
      ref, = Open3.capture3('git', '-C', root, 'rev-parse', 'HEAD')
      ref = ref.strip
      install_fake_github(root)
      File.write(File.join(root, 'message.json'), JSON.generate('title' => 'Fix', 'body' => 'Reason.'))
      yield root, ref, File.join(root, 'mutation.json')
    end
  end

  def commit_repository(root)
    [%w[init --quiet], %w[add .],
     %w[-c user.name=Test -c user.email=test@example.com commit --quiet -m trusted]].each do |args|
      system('git', '-C', root, *args, exception: true)
    end
  end

  def install_fake_github(root)
    bin = File.join(root, 'fake-bin')
    FileUtils.mkdir_p(bin)
    File.write(fake = File.join(bin, 'gh'), FAKE_GH)
    File.chmod(0o755, fake)
  end

  def run_merge(root, ref, mutation, *extra, env: {})
    run_merge_without_walkthrough(root, ref, mutation, '--walkthrough', '17', *extra, env:)
  end

  def run_merge_without_walkthrough(root, ref, mutation, *extra, env: {})
    run_command('merge', 'owner/repo', '1', '--root', root, '--ref', ref, '--head', HEAD, '--base', 'main',
                '--squash-message', File.join(root, 'message.json'), *extra,
                root:, env: { 'MUTATION_FILE' => mutation }.merge(env))
  end

  def run_command(*, root:, env: {})
    Open3.capture3({ 'PATH' => "#{root}/fake-bin:#{ENV.fetch('PATH')}" }.merge(env), *COMMAND, *)
  end
end
