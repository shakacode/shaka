# frozen_string_literal: true

# Fake model and GitHub commands for the command-level opening check tests.
module CliOpeningCheckFakes
  private

  def run_description(dir, root: self.class::ROOT, reviewer: nil, model: nil, ref: nil)
    write_executable(dir, 'gh', fake_gh)
    write_executable(dir, 'claude', fake_claude)
    content = File.join(dir, 'content.json')
    File.write(content, JSON.generate(description_content))
    options = ['--root', root, '--content-file', content]
    options.push('--ref', 'HEAD') if ref.nil? ? reviewer : ref
    options.push('--opening-reviewer', reviewer) if reviewer
    options.push('--opening-model', model) if model
    Open3.capture3({ 'PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'HOME' => dir },
                   self.class::COMMAND, 'description', 'owner/repo', '1', *options)
  end

  def commit(root)
    system('git', '-C', root, 'init', '-q', exception: true)
    system('git', '-C', root, 'add', '.', exception: true)
    system('git', '-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
           'commit', '-qm', 'trusted', exception: true)
  end

  def description_content
    provenance = %w[task_source initial_prompt workflow_version requested_model requested_effort
                    recommended_model recommended_effort active_model active_effort].to_h { |key| [key, 'UNKNOWN'] }
    provenance['task_source'] = 'issue'
    provenance['initial_prompt'] = 'EXCLUDED'
    { 'identity' => { 'agent' => 'Codex' }, 'summary' => self.class::SUMMARY, 'deployment' => 'none',
      'table' => { 'columns' => %w[Check Result], 'rows' => [%w[validate pass]] },
      'provenance' => provenance,
      'details' => [{ 'summary' => 'Usage', 'body' => "| Metric | Value |\n| --- | --- |\n| Total | 1 |" }] }
  end

  def write_executable(dir, name, source)
    path = File.join(dir, name)
    File.write(path, "#!#{RbConfig.ruby}\n#{source}")
    File.chmod(0o755, path)
  end

  def fake_gh
    <<~RUBY
      require 'json'
      request = JSON.parse(STDIN.read)
      case ARGV[1]
      when 'repos/owner/repo/pulls/1'
        if ARGV.include?('PATCH')
          File.write(File.join(ENV.fetch('HOME'), 'published.md'), request.fetch('body'))
          puts JSON.generate(request)
        else
          puts JSON.generate('body' => '')
        end
      when 'markdown' then puts JSON.generate('<table></table>' * 10)
      else abort "unexpected gh request: \#{ARGV.inspect}"
      end
    RUBY
  end

  def fake_claude
    <<~RUBY
      require 'json'
      File.write(File.join(ENV.fetch('HOME'), 'opening-prompt.txt'), STDIN.read)
      File.write(File.join(ENV.fetch('HOME'), 'claude-args.json'), JSON.generate(ARGV))
      abort 'description was not published' unless File.file?(File.join(ENV.fetch('HOME'), 'published.md'))
      File.write(File.join(ENV.fetch('HOME'), 'claude-called'), '')
      sentence = { 'character' => 'shaka merge', 'reader_facing' => false, 'action' => 'checks',
                   'object' => 'head', 'hidden_actions' => [], 'internal_terms' => [] }
      puts JSON.generate('is_error' => false, 'result' => JSON.generate('sentences' => [sentence]))
    RUBY
  end
end
