# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'
require_relative '../skills/shaka-jev/lib/shaka_jev/analysis'

class JevCommandTest < Minitest::Test
  def test_missing_options_and_unreadable_file_have_clean_errors
    command = [File.expand_path('../skills/shaka-jev/scripts/analyze', __dir__),
               '--pr-url', 'https://github.com/shakacode/shaka/pull/302', '--head', 'a' * 40]
    missing, missing_status = Open3.capture2e(*command)
    unreadable, unreadable_status = Open3.capture2e(*command, '--evidence', '/no/such/evidence-file')

    refute_predicate missing_status, :success?
    refute_predicate unreadable_status, :success?
    assert_match(/shaka-jev:/, missing)
    assert_match(/shaka-jev:/, unreadable)
    refute_match(/in ['`]/, unreadable)
  end

  def test_missing_api_key_has_clean_error_before_network_access
    command = [File.expand_path('../skills/shaka-jev/scripts/analyze', __dir__),
               '--pr-url', 'https://github.com/shakacode/shaka/pull/302', '--head', 'a' * 40,
               '--evidence', __FILE__]
    output, status = Open3.capture2e({ 'TYPESAFE_API_KEY' => nil }, *command)

    refute_predicate status, :success?
    assert_match(/TYPESAFE_API_KEY is required/, output)
  end

  def test_oversized_evidence_is_rejected_before_network_access
    Dir.mktmpdir do |dir|
      evidence = File.join(dir, 'large-evidence.txt')
      File.write(evidence, ('x' * ShakaJev::Analysis::MAX_EVIDENCE_BYTES).concat('é'))
      command = [File.expand_path('../skills/shaka-jev/scripts/analyze', __dir__),
                 '--pr-url', 'https://github.com/shakacode/shaka/pull/302', '--head', 'a' * 40,
                 '--evidence', evidence]
      output, status = Open3.capture2e({ 'TYPESAFE_API_KEY' => 'test-key' }, *command)

      refute_predicate status, :success?
      assert_match(/evidence exceeds 64 KiB/, output)
    end
  end

  def test_invalid_api_key_does_not_leak_in_cli_output
    command = [File.expand_path('../skills/shaka-jev/scripts/analyze', __dir__),
               '--pr-url', 'https://github.com/shakacode/shaka/pull/302', '--head', 'a' * 40,
               '--evidence', __FILE__]
    output, status = Open3.capture2e({ 'TYPESAFE_API_KEY' => "test-key\rSECRET" }, *command)

    refute_predicate status, :success?
    assert_match(/TYPESAFE_API_KEY contains invalid characters/, output)
    refute_match(/SECRET/, output)
  end

  def test_success_reads_evidence_and_prints_result
    Dir.mktmpdir do |dir|
      evidence = File.join(dir, 'evidence.txt')
      File.write(evidence, "Public evidence.\n")
      output, status = run_success(evidence)
      assert_predicate status, :success?, output
      assert_equal 'jev-test', JSON.parse(output).fetch('model')
      assert_match(/\A[0-9a-f]{64}\z/, JSON.parse(output).fetch('evidence_sha256'))
    end
  end

  def test_checkout_owned_ruby_cannot_start_helper_with_api_key
    with_candidate_ruby do |dir|
      output, status = run_oversized_with_path(dir)
      refute_predicate status, :success?
      assert_match(/evidence exceeds 64 KiB/, output)
      refute_match(/FAKE RUBY/, output)
    end
  end

  private

  def with_candidate_ruby
    Dir.mktmpdir('jev-ruby-', Dir.pwd) do |dir|
      fake_ruby = File.join(dir, 'ruby')
      File.write(fake_ruby, "#!/bin/sh\nprintf 'FAKE RUBY\\n'\n")
      File.chmod(0o755, fake_ruby)
      yield dir
    end
  end

  def run_oversized_with_path(dir)
    evidence = File.join(dir, 'large-evidence.txt')
    File.write(evidence, 'x' * (ShakaJev::Analysis::MAX_EVIDENCE_BYTES + 1))
    command = [File.expand_path('../skills/shaka-jev/scripts/analyze', __dir__), '--pr-url',
               'https://github.com/shakacode/shaka/pull/302', '--head', 'a' * 40, '--evidence', evidence]
    Open3.capture2e({ 'TYPESAFE_API_KEY' => 'test-key',
                      'PATH' => "#{dir}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}" }, *command)
  end

  def run_success(evidence)
    command = [RbConfig.ruby, File.expand_path('../skills/shaka-jev/scripts/analyze.rb', __dir__),
               '--pr-url', 'https://github.com/shakacode/shaka/pull/302', '--head', 'a' * 40,
               '--evidence', evidence]
    fake = File.expand_path('support/jev_cli_fake.rb', __dir__)
    Open3.capture2e({ 'TYPESAFE_API_KEY' => 'test-key', 'RUBYOPT' => "-r#{fake}" }, *command)
  end
end
