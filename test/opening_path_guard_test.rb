# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../skills/shaka/lib/shaka/local_review/path_guard'

class OpeningPathGuardTest < Minitest::Test
  def test_drops_external_path_directory_with_candidate_executable_symlink
    with_candidate_link do |root, external, safe|
      path = Shaka::LocalReviewPathGuard.safe_path("#{external}:#{safe}", candidate_root: root,
                                                                          drop_candidate: true)
      assert_equal safe, path
      assert_raises(Shaka::Error) { Shaka::LocalReviewPathGuard.safe_path(external, candidate_root: root) }
    end
  end

  def test_uninspectable_external_directory_is_omitted_without_false_accusation
    with_candidate_link do |root, external, safe|
      with_uninspectable(external) do
        path = Shaka::LocalReviewPathGuard.safe_path("#{external}:#{safe}", candidate_root: root)
        assert_equal safe, path
      end
    end
  end

  private

  def with_uninspectable(directory)
    directory = File.realpath(directory)
    original = Dir.method(:children)
    Dir.define_singleton_method(:children) do |path|
      raise Errno::EACCES if path == directory

      original.call(path)
    end
    yield
  ensure
    Dir.define_singleton_method(:children, original)
  end

  def with_candidate_link
    Dir.mktmpdir do |dir|
      root, external, safe = %w[checkout external-bin safe-bin].map do |name|
        File.join(dir, name).tap { |path| Dir.mkdir(path) }
      end
      target = File.join(root, 'gh')
      File.write(target, "#!/bin/sh\nexit 1\n")
      File.chmod(0o755, target)
      File.symlink(target, File.join(external, 'gh'))
      yield File.realpath(root), external, safe
    end
  end
end
