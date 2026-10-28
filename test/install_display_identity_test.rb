# frozen_string_literal: true

require_relative 'install_support'
require 'shaka/install/tree'

class InstallDisplayIdentityTest < Minitest::Test
  include InstallTestSupport

  def test_content_and_hash_edits_cannot_keep_the_original_package_identity
    install!
    metadata = package_identity
    File.write(File.join(@destination, 'scripts/shaka'), "#!/usr/bin/env ruby\nputs 'changed'\n")
    rewrite_package_hash(metadata)
    assert_identity_rejected('--skills-dir', @skills_dir, '--with-rct')
  end

  private

  def install!
    output, status = install
    assert_predicate status, :success?, output
  end

  def rewrite_package_hash(metadata)
    metadata.fetch('source')['package_content_sha256'] = Shaka::Install::Tree.new(metadata.fetch('skills')).hash(package_path)
    File.write(File.join(package_path, '.shaka-install.json'), JSON.generate(metadata))
  end

  def assert_identity_rejected(*)
    output, status = run_installer(*)
    refute_predicate status, :success?
    assert_includes output, 'Managed package identity differs'
  end
end
