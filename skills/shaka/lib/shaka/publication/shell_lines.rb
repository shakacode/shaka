# frozen_string_literal: true

require 'json'
require 'shellwords'

module Shaka
  # Splits a shell tool call's command text into the command lines it runs and their words, leaving
  # quoted arguments and here-document bodies whole.
  module ShellLines
    # Exactly `<<`, not a here-string's `<<<`, then a word; a delimiter starts with a letter or underscore.
    HEREDOC = /(?<!<)<<(?!<)-?\s*([A-Za-z_]\w*)/
    # `$((1 << 3))` shifts bits; it opens no here-document, so it is removed before the search.
    ARITHMETIC = /\$\(\((?:[^()]|\([^()]*\))*\)\)/
    # Codex runs shell lines from JavaScript, as `exec_command({cmd:"..."})`.
    SCRIPT_COMMAND = /\bcmd:\s*("(?:[^"\\]|\\.)*")/

    module_function

    # Only Codex's JavaScript `exec` tool wraps its shell lines in `cmd:"..."`; for any other tool that
    # text is an argument, not a command.
    def lines(name, command)
      scripts = name == 'exec' ? command.scan(SCRIPT_COMMAND).map { |(literal)| unquote(literal) } : []
      (scripts.empty? ? [command] : scripts).flat_map { |text| segments(text) }
    end

    # Splits command lines at `;`, `&`, `|`, and newlines outside quotes, so a quoted commit message or
    # PR body stays one argument.
    def segments(text)
      tokens = without_heredocs(text).scan(/"(?:\\.|[^"\\])*"?|'[^']*'?|[;&|\n]|[^"';&|\n]+/)
      parts = tokens.each_with_object([+'']) do |token, lines|
        token.match?(/\A[;&|\n]\z/) ? lines << +'' : lines.last << token
      end
      parts.map(&:strip).reject(&:empty?)
    end

    # Drops each here-document's body, which is input to a command, not a command line.
    def without_heredocs(text)
      ending = nil
      text.each_line.with_object(+'') do |line, kept|
        if ending
          ending = nil if line.strip == ending
        else
          kept << line
          ending = heredoc_end(line)
        end
      end
    end

    # The word that ends a here-document this line opens outside quotes, such as EOF in `<<'EOF'`.
    def heredoc_end(line)
      tokens = line.gsub(ARITHMETIC, '').scan(/"(?:\\.|[^"\\])*"?|'[^']*'?|[^"']+/)
      tokens.each_with_index do |token, at|
        next if token.start_with?('"', "'")

        word = token[HEREDOC, 1]
        return word if word

        quoted = tokens[at + 1].to_s
        return quoted[1...-1] if token.match?(/(?<!<)<<-?\s*\z/) && quoted.match?(/\A(['"])\w+\1\z/)
      end
      nil
    end

    def unquote(literal)
      JSON.parse(literal)
    rescue JSON::ParserError
      literal[1...-1]
    end

    def words(line)
      Shellwords.split(line)
    rescue ArgumentError
      line.split
    end
  end
end
