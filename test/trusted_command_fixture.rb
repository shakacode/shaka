# frozen_string_literal: true

require_relative 'evidence_fixture'

# A branch cut before the repository added its Shaka settings has no command directory.
module TrustedCommandFixture
  include EvidenceFixture

  # Finds the checkout the way generated commands do, then proves it sees the candidate's own file.
  VALIDATE = <<~SH
    #!/bin/sh
    set -eu
    root=$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)
    test -f "$root/candidate.txt"
    echo "validated $root"
  SH

  private

  def trusted_copy(root, trusted)
    Shaka::Evidence::TrustedCommand.new(root, trusted, '.agents/shaka/bin/validate')
  end

  def refused_run(root, trusted)
    _output, error = capture_io do
      assert_equal 1, Shaka::Evidence::Command.run(
        ['run', '--root', root, '--ref', trusted, '--repository', 'shakacode/shaka', '--command', 'validate']
      )
    end
    error
  end

  # The trusted commit has the settings; the candidate commit after it removes them, like an older branch.
  def with_older_branch(validate: VALIDATE)
    with_checkout do |root, _initial|
      File.write(File.join(root, '.agents/shaka/bin/validate'), validate)
      trusted = commit_all(root)
      git(root, 'rm', '-r', '--quiet', '.agents')
      File.write(File.join(root, 'candidate.txt'), "older branch\n")
      yield root, trusted, commit_all(root)
    end
  end

  def commit_all(root)
    git(root, 'add', '-A')
    commit(root)
    git(root, 'rev-parse', 'HEAD')
  end
end
