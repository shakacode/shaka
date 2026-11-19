# frozen_string_literal: true

require 'digest'
require 'json'
require 'open3'
require 'tmpdir'

module Shaka
  module Evaluation
    # Keep each call's report and usage before its temporary artifacts are removed.
    module ReviewReplayRecords
      private

      def capture_record(arguments, root, id)
        Dir.mktmpdir('call-', @scratch) do |temporary|
          env = @environment.merge('TMPDIR' => temporary)
          before = native_sessions
          output, error, status = Open3.capture3(env, @helper, *arguments, chdir: root, binmode: true)
          result = retain_result(parse_result(output), id)
          retain_failed_sessions(result, id, before) unless status.success? && result['status'] == 'completed'
          [{ 'result' => result, 'usage' => usage_for(result), 'stderr' => json_text(error) }, status]
        end
      end

      def parse_result(output)
        text = output.dup.force_encoding(Encoding::UTF_8)
        return { 'invalid_output' => json_text(output) } unless text.valid_encoding?

        result = JSON.parse(text)
        return result if result.is_a?(Hash)

        { 'invalid_output' => json_text(output) }
      rescue JSON::ParserError, EncodingError
        { 'invalid_output' => json_text(output) }
      end

      def json_text(bytes)
        text = bytes.dup.force_encoding(Encoding::UTF_8)
        text.valid_encoding? ? text : { 'base64' => [bytes].pack('m0') }
      end

      def native_sessions
        home = @environment['CODEX_HOME']
        home ? Dir.glob(File.join(home, 'sessions', '**', '*.jsonl')) : []
      end

      def retain_failed_sessions(result, id, before)
        result['native_sessions'] = (native_sessions - before).map.with_index do |source, index|
          path = File.join(@directory, "#{id}.failed-#{index}.jsonl")
          copy_private(source, path)
          path
        end
      end

      def retain_result(result, id)
        if result['usage']
          path = File.join(@directory, "#{id}.usage.jsonl")
          copy_private(result['usage'], path)
          result['usage'] = path
        end
        result['report'] = json_text(File.binread(result['report'])) if result['report']
        result['diagnostic'] = json_text(File.binread(result.delete('diagnostic_path'))) if result['diagnostic_path']
        result
      end

      def save_run(id, case_id, arm, record)
        metadata = { 'case' => case_id, 'arm' => arm, 'selection' => @options.fetch(arm) }
        bytes = "#{JSON.pretty_generate(record.merge(metadata))}\n"
        File.open(File.join(@directory, "#{id}.json"), 'wx', 0o600) do |file|
          file.write(bytes)
          file.fsync
        end
        puts "#{case_id} #{arm} record #{id}"
        "sha256:#{Digest::SHA256.hexdigest(bytes)}"
      end
    end
  end
end
