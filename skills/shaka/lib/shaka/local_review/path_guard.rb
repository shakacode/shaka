# frozen_string_literal: true

# Keeps candidate-owned executables and script interpreters out of command PATHs.

require_relative '../error'
require_relative 'executable'

module Shaka
  # Screens command lookup paths before candidate data can influence a process.
  module LocalReviewPathGuard
    GUARDED_EXECUTABLES = %w[gh git claude codex grok].freeze

    def self.safe_path(path, candidate_root:, drop_candidate: false, inspect_links: true, all_executables: false)
      entries = path.split(File::PATH_SEPARATOR, -1)
      names = guarded_names(entries, candidate_root) if inspect_links
      options = { drop_candidate:, inspect_links:, all_executables:, names: }
      entries.filter_map do |entry|
        normalized_path_entry(entry, candidate_root, options)
      end
             .join(File::PATH_SEPARATOR)
    end

    def self.normalized_path_entry(entry, candidate_root, options)
      directory = File.expand_path(entry.empty? ? '.' : entry)
      return directory unless File.directory?(directory)

      state = candidate_path_state(File.realpath(directory), candidate_root, options)
      return if state == :uninspectable
      return directory if state == :safe
      return if options[:drop_candidate]

      raise Shaka::Error, 'PATH entry resolves inside candidate checkout'
    end

    def self.candidate_path_state(directory, candidate_root, options)
      return :candidate if LocalReviewExecutable.candidate_owned?(directory, candidate_root)
      return :safe unless options[:inspect_links]

      linked = candidate_executable_link?(directory, candidate_root, options)
      return :uninspectable if linked == :uninspectable

      linked ? :candidate : :safe
    end

    def self.candidate_executable_link?(directory, candidate_root, options)
      names = options[:all_executables] ? Dir.children(directory) : options[:names]
      names.any? do |name|
        path = File.join(directory, name)
        File.symlink?(path) && File.executable?(path) &&
          LocalReviewExecutable.candidate_owned?(File.realpath(path), candidate_root)
      end
    rescue SystemCallError
      :uninspectable # Omit a PATH directory that cannot be inspected.
    end

    def self.guarded_names(entries, candidate_root)
      interpreters = GUARDED_EXECUTABLES.filter_map do |name|
        executable = first_executable(entries, name)
        interpreter_name(executable, name, candidate_root) if executable
      end
      (GUARDED_EXECUTABLES + interpreters).uniq
    end

    def self.first_executable(entries, name)
      entries.each do |entry|
        directory = File.expand_path(entry.empty? ? '.' : entry)
        executable = File.join(directory, name)
        return executable if File.file?(executable) && File.executable?(executable)
      end
      nil
    end

    def self.interpreter_name(executable, name, candidate_root)
      interpreter = shebang_interpreter(executable)
      return unless interpreter

      unsafe = interpreter.start_with?('/') &&
               LocalReviewExecutable.candidate_owned?(File.realpath(interpreter), candidate_root)
      raise Shaka::Error, "#{name} interpreter resolves inside candidate checkout" if unsafe

      File.basename(interpreter)
    end

    def self.shebang_interpreter(executable)
      line = File.open(executable, 'rb') { |file| file.read(256).to_s.lines.first.to_s }
      return unless line.start_with?('#!')

      words = line.delete_prefix('#!').split
      return unless words.first
      return env_interpreter(words) if File.basename(words.first) == 'env'

      words.first
    end

    def self.env_interpreter(words)
      arguments = env_arguments(words.drop(1))
      interpreter = arguments.drop_while { |word| word.match?(/\A[A-Za-z_][A-Za-z0-9_]*=/) }.first
      raise Shaka::Error, 'Cannot determine env shebang interpreter' if interpreter.nil? || interpreter.start_with?('-')

      interpreter
    end

    def self.env_arguments(arguments)
      arguments.shift if arguments.first == '-S'
      arguments[0] = arguments.first.delete_prefix('-S') if arguments.first&.start_with?('-S')
      arguments
    end

    private

    def validate_path!
      ENV['PATH'] = LocalReviewPathGuard.safe_path(ENV.fetch('PATH', ''), candidate_root: root,
                                                                          all_executables: true)
    end
  end
end
