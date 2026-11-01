# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/evidence/relevant_code'
require 'tmpdir'

# Walks the require graph of the code that runs and checks evidence.
module EvidenceRequireGraph
  LIB = File.expand_path('../skills/shaka/lib/shaka', __dir__)
  ENTRY_POINTS = %w[evidence/command.rb evidence/review.rb evidence/result.rb evidence/verification.rb
                    local_review.rb local_review/runner.rb local_review/report_check.rb review_prompt.rb].freeze
  # Rendering and GitHub calls show results without changing them, and settings code reaches
  # evidence only through its output, which the fingerprint already covers.
  OUTSIDE = %r{\A(?:publication|github|public_comments|walkthrough|post_implementation|handoff|opening_|hosts/|merge|
                 attention|ready_time|review_thread|review_coverage|pending_review|published_results|usage|gitlab|
                 install/|repository_config|configuration(?!/fingerprint)|defaults|trusted_|doctor/)}x

  module_function

  def files
    seen = []
    queue = ENTRY_POINTS.dup
    until queue.empty?
      path = queue.shift
      next if seen.include?(path) || !followed?(path)

      seen << path
      queue.concat(requires(path))
    end
    seen
  end

  def followed?(path)
    File.file?(File.join(LIB, path)) && (ENTRY_POINTS.include?(path) || !path.match?(OUTSIDE))
  end

  def requires(path)
    full = File.join(LIB, path)
    File.read(full, encoding: 'UTF-8').scan(/require_relative\s+['"]([^'"]+)['"]/).flatten.map do |required|
      File.expand_path("#{required}.rb", File.dirname(full)).delete_prefix("#{LIB}/")
    end
  end
end

# https://github.com/shakacode/shaka/issues/956: every install update superseded validation and
# review of an unchanged commit, whatever the update touched.
class EvidenceRelevantCodeTest < Minitest::Test
  include EvidenceFixture

  def test_an_update_outside_the_relevant_code_keeps_validation_and_review_bound
    with_checkout do |root, ref|
      validation = run_check(root, ref, command: 'validate')
      review = review_check(root, ref)
      installed(revision: 'b' * 40) do
        assert_equal 'bound', bind(root, ref, ref, validation).fetch('status')
        assert_equal 'bound', bind(root, ref, ref, review).fetch('status')
      end
    end
  end

  def test_a_change_to_the_relevant_code_supersedes_validation_and_review
    with_checkout do |root, ref|
      results = [run_check(root, ref, command: 'validate'), review_check(root, ref)]
      relevant_code('changed') do
        results.map { bind(root, ref, ref, it) }.each do |binding|
          assert_equal ['settings components differ: installation'], binding.fetch('reasons')
          assert_equal 'superseded', binding.fetch('status')
        end
      end
    end
  end

  def test_a_new_version_supersedes_results_as_a_release_boundary
    with_checkout do |root, ref|
      validation = run_check(root, ref, command: 'validate')
      installed(version: '99.0.0') do
        assert_includes bind(root, ref, ref, validation).fetch('reasons'), 'settings components differ: installation'
      end
    end
  end

  def test_an_update_during_a_check_voids_it_only_when_it_changes_relevant_code
    with_checkout do |root, ref|
      refute updating_during_check { run_check(root, ref, command: 'validate') }.fetch('inputs_changed')
      voided = relevant_code_changing_during_check { run_check(root, ref, command: 'validate', expected_exit: 1) }
      assert voided.fetch('inputs_changed')
      assert_equal 'not_completed', voided.fetch('status')
    end
  end

  def test_the_digest_follows_relevant_files_and_ignores_the_rest
    Dir.mktmpdir do |root|
      relevant, other = %w[evidence/result.rb publication/publication.rb].map { File.join(root, 'lib/shaka', it) }
      [relevant, other].each { write_file(it, 'first') }
      first = Shaka::Evidence::RelevantCode.digest(root:)
      write_file(other, 'second')
      assert_equal first, Shaka::Evidence::RelevantCode.digest(root:)
      write_file(relevant, 'second')
      refute_equal first, Shaka::Evidence::RelevantCode.digest(root:)
    end
  end

  def test_the_review_prompts_count_as_relevant_and_description_republishing_does_not
    files = Shaka::Evidence::RelevantCode.files
    refute_includes files, 'lib/shaka/published_results.rb'
    assert_includes files, 'config/review-prompt.md'
    assert_includes files, 'config/review-instructions-precedence.md'
  end

  # A new require from evidence or review code fails here until it is listed or classified,
  # so the fixed list cannot quietly let a result from changed review code bind.
  def test_every_file_evidence_and_review_code_requires_is_relevant_or_classified
    listed = Shaka::Evidence::RelevantCode.files
    unlisted = EvidenceRequireGraph.files.reject { |path| listed.include?("lib/shaka/#{path}") }
    assert_empty unlisted
  end

  private

  def write_file(path, text)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, text)
  end

  def installed(version: nil, revision: nil, &)
    current = Shaka::Doctor::InstallationIdentity.read
    source = current.fetch('source').merge('revision' => revision, 'content_sha256' => revision)
    updated = current.merge('version' => version || current.fetch('version'))
    updated = updated.merge('source' => source) if revision
    replacing(Shaka::Doctor::InstallationIdentity, :read, proc { updated }, &)
  end

  def relevant_code(digest, &) = replacing(Shaka::Evidence::RelevantCode, :digest, proc { digest }, &)

  # Each capture sees a newer revision, as when the install moves while the check runs.
  def updating_during_check(&)
    current = Shaka::Doctor::InstallationIdentity.read
    reads = 0
    reader = proc do
      reads += 1
      current.merge('source' => current.fetch('source').merge('revision' => reads.to_s.rjust(40, '0')))
    end
    replacing(Shaka::Doctor::InstallationIdentity, :read, reader, &)
  end

  def relevant_code_changing_during_check(&)
    reads = 0
    replacing(Shaka::Evidence::RelevantCode, :digest, proc { (reads += 1).to_s }, &)
  end

  def replacing(object, name, replacement)
    original = object.method(name)
    object.define_singleton_method(name, &replacement)
    yield
  ensure
    object.define_singleton_method(name, original)
  end
end
