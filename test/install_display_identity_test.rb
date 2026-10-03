# frozen_string_literal: true

require_relative 'install_support'
require 'yaml'
require 'shaka/install/package'
require 'shaka/install/tree'

class InstallDisplayIdentityTest < Minitest::Test
  include InstallTestSupport

  def test_legacy_package_without_generated_metadata_remains_usable
    metadata = make_legacy_package
    output, status = run_installer('--skills-dir', @skills_dir, '--with-rct',
                                   '--rollback', metadata.fetch('package_id'))
    assert_predicate status, :success?, output
    install!
    assert_match(/\AShaka /, interface.fetch('display_name'))
    refute_equal metadata.fetch('package_id'), package_identity.fetch('package_id')
  end

  def test_content_and_hash_edits_cannot_keep_the_original_package_identity
    install!
    metadata = package_identity
    File.write(File.join(@destination, 'scripts/shaka'), "#!/usr/bin/env ruby\nputs 'changed'\n")
    rewrite_package_hash(metadata)
    assert_identity_rejected('--skills-dir', @skills_dir, '--with-rct', '--rollback', metadata.fetch('package_id'))
    assert_identity_rejected('--skills-dir', @skills_dir, '--with-rct')
  end

  private

  def interface = YAML.safe_load_file(File.join(@destination, 'agents/openai.yaml')).fetch('interface')

  def install!
    output, status = install
    assert_predicate status, :success?, output
  end

  def make_legacy_package
    install!
    old_path = package_path
    metadata = legacy_metadata
    FileUtils.remove_entry(File.join(@destination, 'agents'))
    File.write(File.join(old_path, '.shaka-install.json'), JSON.generate(metadata))
    relocate_legacy(old_path, metadata.fetch('package_id'))
    metadata
  end

  def legacy_metadata
    metadata = package_identity
    metadata['source'] = metadata.fetch('source').except('package_content_sha256')
    metadata['package_id'] = Shaka::Install::Package.identity_for(metadata.fetch('version'), metadata.fetch('source'))
    metadata
  end

  def relocate_legacy(old_path, id)
    target = File.join(File.dirname(old_path), id)
    File.rename(old_path, target)
    File.unlink(@destination)
    File.symlink(File.join(target, 'skills/shaka'), @destination)
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
