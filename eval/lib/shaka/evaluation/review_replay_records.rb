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
          output, error, status = Open3.capture3(env, @helper, *arguments, chdir: root)
          result = retain_result(parse_result(output), id)
          [{ 'result' => result, 'usage' => usage_for(result), 'stderr' => error }, status]
        end
      end

      def parse_result(output)
        result = JSON.parse(output)
        return result if result.is_a?(Hash)

        { 'invalid_output' => output }
      rescue JSON::ParserError
        { 'invalid_output' => output }
      end

      def retain_result(result, id)
        if result['usage']
          path = File.join(@directory, "#{id}.usage.jsonl")
          copy_private(result['usage'], path)
          result['usage'] = path
        end
        result['report'] = File.read(result['report']) if result['report']
        result['diagnostic'] = File.read(result.delete('diagnostic_path')) if result['diagnostic_path']
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
