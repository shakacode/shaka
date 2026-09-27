# frozen_string_literal: true

# Fake model and GitHub commands for the command-level opening check tests.
module CliOpeningCheckFakes
  private

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
      STDIN.read
      File.write(File.join(ENV.fetch('HOME'), 'claude-called'), '')
      sentence = { 'character' => 'shaka merge', 'reader_facing' => false, 'action' => 'checks',
                   'object' => 'head', 'hidden_actions' => [], 'internal_terms' => [] }
      puts JSON.generate('is_error' => false, 'result' => JSON.generate('sentences' => [sentence]))
    RUBY
  end
end
