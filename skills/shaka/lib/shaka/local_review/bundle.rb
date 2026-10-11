# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'tmpdir'
require_relative '../error'

module Shaka
  # Keeps a copy of each report beside its ledger, named by content hash, so a review outlives the
  # reviewer's temporary files. A round names its copy by full path, as every reader of a ledger
  # expects, and by hash, which finds the copy again after the directory moves. A round without a
  # hash predates this and still names the reviewer's own file.
  module LocalReviewBundle
    VERSION = 2
    DIRECTORY = 'reports'

    module_function

    # The round fields naming the kept copy. Nothing is returned, and no round appended, unless the
    # copy holds exactly what was read.
    def store(ledger_path, report)
      text = File.binread(report)
      digest = Digest::SHA256.hexdigest(text)
      kept = kept_path(File.dirname(ledger_path), digest)
      write(kept, text)
      { 'report' => kept, 'report_sha256' => digest }
    rescue SystemCallError => e
      raise Error, "The review report could not be kept beside the ledger (#{e.message}); no round was added."
    end

    # A ledger this Shaka can read. A newer format is refused, never rewritten as an older one.
    def ledger!(parsed, path)
      raise Error, "#{path} is not a review ledger." unless parsed.is_a?(Hash) && parsed['rounds'].is_a?(Array)
      raise Error, "#{path} was written by a newer Shaka; update Shaka to use it." if
        parsed['version'].to_i > VERSION

      parsed
    end

    # The content with every report as a readable absolute path, or an error naming the round whose
    # report is gone or no longer matches its hash. A hash detects a change; it cannot restore one.
    def resolve(content, directory)
      rounds = content['rounds']
      return content unless rounds.is_a?(Array)

      content.merge('rounds' => rounds.each_with_index.map { |round, index| resolved(round, directory, index + 1) })
    end

    def kept_path(directory, digest) = File.join(directory, DIRECTORY, "#{digest}.md")

    def warning(ledger_path)
      directory = File.dirname(File.expand_path(ledger_path))
      temporary = File.realpath(Dir.tmpdir)
      return unless [directory, (File.realpath(directory) if File.directory?(directory))].compact.any? do |candidate|
        candidate == temporary || candidate.start_with?("#{temporary}/")
      end

      'The ledger is in a temporary directory and will be lost with it. Keep each task\'s ledger in its own ' \
        'directory under ~/.local/state/shaka/reviews/.'
    end

    def resolved(round, directory, number)
      return round unless round.is_a?(Hash) && round['report'].is_a?(String)

      expected = round['report_sha256']
      file = located(round['report'], expected, directory)
      unavailable!(number, "#{round['report']} is missing") unless file
      unavailable!(number, "#{file} changed after it was kept") if
        expected && Digest::SHA256.file(file).hexdigest != expected

      round.merge('report' => file)
    end

    # The recorded path, or the copy beside a ledger that has moved since the round was added.
    def located(recorded, digest, directory)
      [recorded, (kept_path(directory, digest) if digest)].compact.find { |file| File.file?(file) }
    end

    def unavailable!(number, reason)
      raise Error, "Round #{number}'s report is unavailable: #{reason}."
    end

    def write(target, text)
      return if File.file?(target) && File.binread(target) == text

      FileUtils.mkdir_p(File.dirname(target), mode: 0o700)
      temporary = "#{target}.#{Process.pid}.tmp"
      File.binwrite(temporary, text, perm: 0o600)
      File.rename(temporary, target)
    end

    private_class_method :resolved, :located, :unavailable!, :write
  end
end
