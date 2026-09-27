# frozen_string_literal: true

require_relative '../error'
require_relative 'executable'

module Shaka
  # Refuses candidate-controlled PATH entries before any external command runs.
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
      (GUARDED_EXECUTABLES + entries.flat_map { |entry| interpreter_names(entry, candidate_root) }).uniq
    end

    def self.interpreter_names(entry, candidate_root)
      directory = File.expand_path(entry.empty? ? '.' : entry)
      return [] unless File.directory?(directory)

      GUARDED_EXECUTABLES.filter_map do |name|
        interpreter_name(File.join(directory, name), name, candidate_root)
      end
    end

    def self.interpreter_name(executable, name, candidate_root)
      return unless File.file?(executable) && File.executable?(executable)

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
      words.drop(1).find { |word| !word.start_with?('-') }
    end

    private

    def validate_path!
      ENV['PATH'] = LocalReviewPathGuard.safe_path(ENV.fetch('PATH', ''), candidate_root: root,
                                                                          all_executables: true)
    end
  end
end
