# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/post_implementation'

class PostImplementationPublicationTest < Minitest::Test
  class GitHub
    attr_reader :bodies

    def initialize(head)
      @head = head
      @bodies = []
    end

    def verify_head(head)
      raise Shaka::Error, 'stale' unless head == @head
    end

    def reply(body:, key:)
      @bodies << [body, key]
      { 'url' => 'https://github.com/example/test/pull/1#issuecomment-1' }
    end
  end

  def test_publication_keeps_execution_metadata_without_private_native_content
    with_result do |result, path|
      attach_private_usage(result, path)
      github, status = publish(result, path)

      assert_equal 0, status
      assert_includes github.bodies.first.first, 'observed-model'
      refute_includes github.bodies.first.first, 'PRIVATE TRANSCRIPT'
    end
  end

  def test_stale_head_and_technical_evidence_cannot_be_published_as_checkpoint
    with_result do |result, path|
      result['head'] = 'b' * 40
      github, status = publish(result, path)

      assert_equal 1, status
      assert_empty github.bodies
      result['head'] = 'a' * 40
      result['purpose'] = 'technical_review'
      assert_equal 1, publish(result, path).last
    end
  end

  def test_another_execution_does_not_overwrite_the_earlier_conclusion
    with_result do |result, path|
      first, = publish(result, path)
      result['execution_id'] = 'def56789'
      second, = publish(result, path)

      refute_equal first.bodies.first.last, second.bodies.first.last
    end
  end

  private

  def attach_private_usage(result, path)
    usage = File.join(File.dirname(path), 'usage.json')
    File.write(usage, JSON.generate(type: 'result', result: 'PRIVATE TRANSCRIPT', session_id: 'test',
                                    model: 'observed-model', usage: { input_tokens: 17, output_tokens: 2 }))
    result['usage'] = usage
    result['reviewer'] = 'anthropic/claude'
  end

  def with_result
    Dir.mktmpdir do |root|
      report = File.join(root, 'report.json')
      File.write(report, JSON.generate(head: 'a' * 40, conclusion: 'Proceed', reasons: ['Useful change'],
                                       concerns: [], alternative: 'No change leaves the bug'))
      result = { 'purpose' => 'post_implementation', 'status' => 'completed', 'head' => 'a' * 40,
                 'report' => report, 'reviewer' => 'openai/codex', 'effort' => 'medium',
                 'prompt_source' => 'Shaka default', 'execution_id' => 'abc12345' }
      yield result, File.join(root, 'result.json')
    end
  end

  def publish(result, path)
    File.write(path, JSON.generate(result))
    github = GitHub.new('a' * 40)
    status = nil
    capture_io do
      status = Shaka::PostImplementation.run(['publish', 'example/test', '1', '--content-file', path], github:)
    end
    [github, status]
  end
end
