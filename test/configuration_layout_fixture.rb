# frozen_string_literal: true

require_relative 'repository_fixture'

module ConfigurationLayoutFixture
  include RepositoryConfigTestHelpers

  def with_new_layout
    Dir.mktmpdir('shaka-new-layout') do |root|
      FileUtils.mkdir_p(File.join(root, '.agents/shaka/bin'))
      create_new_commands(root)
      File.write(File.join(root, '.agents/shaka/config.yml'), YAML.dump(config))
      yield root
    end
  end

  def create_new_commands(root) = create_commands_at(root, '.agents/shaka/bin')

  def create_commands_at(root, directory)
    %w[setup validate test].each do |name|
      path = File.join(root, directory, name)
      File.write(path, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, path)
    end
  end

  def commit_fixture(root)
    system('git', '-C', root, 'init', '--quiet', exception: true)
    system('git', '-C', root, 'add', '.', exception: true)
    system('git', '-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
           'commit', '--quiet', '-m', 'layout fixture', exception: true)
  end

  def write_new_prompt_config(root)
    path = File.join(root, '.agents/shaka/config.yml')
    policy = config.merge('review' => review_policy('replacement_prompt_file' => '.agents/shaka/review-prompt.md'))
    File.write(path, YAML.dump(policy))
    File.write(File.join(root, '.agents/shaka/review-prompt.md'), "Review instructions\n")
  end
end
