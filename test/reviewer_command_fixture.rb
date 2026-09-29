# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'tmpdir'
require 'yaml'

# A throwaway repository whose seam lists Claude, Codex, and Grok, and a runner for `shaka reviewer`.
module ReviewerCommandFixture
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  private

  def reviewer(root, *)
    output, error, status = Open3.capture3(COMMAND, 'reviewer', '--root', root, *)
    raise error unless status.success?

    JSON.parse(output)
  end

  def rewrite_reviewers(root, reviewers)
    path = File.join(root, '.agents/agent-workflow.yml')
    config = YAML.safe_load_file(path)
    config['review']['local_review_agents'] = reviewers
    File.write(path, YAML.dump(config))
  end

  def with_repository
    Dir.mktmpdir('shaka-reviewer') do |root|
      FileUtils.mkdir_p(File.join(root, '.agents/bin'))
      %w[setup validate test].each { |name| write_command(root, name) }
      File.write(File.join(root, '.agents/agent-workflow.yml'), YAML.dump(config))
      yield root
    end
  end

  def write_command(root, name)
    path = File.join(root, '.agents/bin', name)
    File.write(path, "#!/bin/sh\nexit 0\n")
    File.chmod(0o755, path)
  end

  def config
    { 'version' => 1, 'base_branch' => 'main',
      'review' => { 'required' => 'meaningful_changes', 'ci_review_jobs' => ['claude-review'],
                    'local_review_agents' => [{ 'provider' => 'anthropic', 'model_family' => 'claude' },
                                              { 'provider' => 'openai', 'model_family' => 'codex' },
                                              { 'provider' => 'xai', 'model_family' => 'grok' }] },
      'merge' => { 'preference' => 'ask' } }
  end
end
