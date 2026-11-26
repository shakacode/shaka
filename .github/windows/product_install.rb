# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'tmpdir'

# The Windows install scenarios: each installs this checkout's head into a fresh home and requires
# the saved identity to be that exact revision.
module WindowsProductInstall
  INSTALLS = { 'bin/install installs and verifies the helper' => :install_and_verify,
               'documented Windows install of a cloned checkout' => :documented_install }.freeze

  private

  # Installs this checkout's head, not upstream main, from a local branch the installer clones.
  # The branch name is new for each run, and only a branch this run created is deleted.
  def install
    head = git_output('rev-parse', 'HEAD')
    branch = "shaka-windows-candidate-#{SecureRandom.hex(6)}"
    git_output('branch', branch, 'HEAD')
    created = branch
    check_install(head, *Dir.mktmpdir('shaka-windows-install') { |home| yield home, branch })
  ensure
    delete_branch(created) if created
  end

  # Cleanup reports a failed delete instead of hiding the install's own error.
  def delete_branch(branch)
    git_output('branch', '--delete', '--force', branch)
  rescue RuntimeError => e
    puts "  cleanup: #{e.message}"
  end

  # The installer prints the revision it verified, abbreviated to however many digits Git chooses.
  def verified?(output, head)
    output[/^Verified Shaka installation: .* \((\h{7,40})\)\r?$/, 1].then { |shown| shown && head.start_with?(shown) }
  end

  # The second run reads the record the first one saved, as a later --verify or --update does.
  def install_and_verify(home, branch)
    installed, installed_ok = run_installer(home, '--agent', 'codex', '--repository', root, '--branch', branch)
    checked, checked_ok = run_installer(home, '--verify')
    puts "  --verify #{checked_ok ? 'succeeded' : 'failed'}: #{excerpt(checked)}"
    [installed, installed_ok && checked_ok, saved_source(home)]
  end

  def check_install(head, output, success, source)
    puts "  #{success ? 'succeeded' : 'failed'}: #{excerpt(output)}"
    puts "  saved identity: #{source.inspect}"
    raise "bin/install did not verify candidate #{head}" unless success && verified?(output, head)
    return if source == { 'kind' => 'revision', 'revision' => head }

    raise "bin/install did not save the exact revision #{head}"
  end

  # The manual installation guide's Windows recipe: clone with stored line endings, then install that
  # checkout itself.
  def documented_install(home, branch)
    directory = File.join(home, '.local/share/shaka/source')
    cloned = system(git_environment, 'git', 'clone', '--quiet', '--config', 'core.autocrlf=false', '--config',
                    'core.eol=lf', '--branch', branch, root, directory)
    raise 'git clone failed' unless cloned

    output, success = run_installer(home, '--directory', directory, '--repository', root, '--branch', branch,
                                    '--agent', 'codex')
    [output, success, saved_source(home)]
  end

  # The record's source identity says whether the install counted as the exact revision.
  def saved_source(home)
    record = File.join(home, '.local/share/shaka/source/.git/shaka-install.json')
    File.file?(record) ? JSON.parse(File.read(record)).dig('identity', 'source')&.slice('kind', 'revision') : nil
  end

  # Bounded, so a hung install fails the record instead of holding the job.
  def run_installer(home, *arguments)
    environment = native_path.merge('HOME' => home, 'USERPROFILE' => home)
    output, error, success = capture([environment, RbConfig.ruby, File.join(root, 'bin/install'), *arguments], 600)
    ["#{output}#{error}", success]
  end
end
