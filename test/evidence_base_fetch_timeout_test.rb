# frozen_string_literal: true

require_relative 'evidence_fixture'

class EvidenceBaseFetchTimeoutTest < Minitest::Test
  include EvidenceFixture

  def test_a_stalled_fetch_is_killed_with_its_transport_children
    with_checkout do |root, _ref|
      Dir.mktmpdir('shaka-base-stall-') do |directory|
        pid_file = stalling_origin(root, directory)
        report = Shaka::Evidence::BaseFreshness.check(root:, base: 'main', fetch_seconds: 3)

        assert_equal 'unknown', report.fetch('behind')
        assert gone?(Integer(File.read(pid_file))), 'the transport child must not outlive the fetch'
      end
    end
  end

  private

  # A killed orphan can linger until launchd or init reaps it.
  def gone?(pid)
    50.times do
      Process.kill(0, pid)
      sleep 0.1
    end
    false
  rescue Errno::ESRCH
    true
  end

  # The transport starts a child and waits on it, as an SSH fetch would.
  def stalling_origin(root, directory)
    pid_file = File.join(directory, 'child.pid')
    transport = File.join(directory, 'stall')
    File.write(transport, "#!/bin/sh\nsleep 30 &\necho $! > '#{pid_file}'\nwait\n")
    File.chmod(0o755, transport)
    git(root, 'config', 'protocol.ext.allow', 'always')
    git(root, 'remote', 'add', 'origin', "ext::#{transport}")
    pid_file
  end
end
