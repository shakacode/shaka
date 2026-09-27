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

  private

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
