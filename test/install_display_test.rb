# frozen_string_literal: true

require_relative 'install_support'
require 'yaml'

class InstallDisplayTest < Minitest::Test
  include InstallTestSupport

  def test_revision_package_displays_version_and_commit_without_changing_source
    revision = commit_source
    install!

    assert_equal "Shaka 0.1.0.pre.1 (#{revision[0, 7]})", interface.fetch('display_name')
    assert_includes interface.fetch('default_prompt'), '$shaka'
    refute_path_exists File.join(@source, 'agents/openai.yaml')
    assert_equal revision, package_identity.dig('source', 'revision')
    install!
  end

  def test_development_packages_have_distinct_labels
    assert_predicate install.last, :success?
    first = interface.fetch('display_name')
    assert_match(/\AShaka 0\.1\.0\.pre\.1 \(dev [0-9a-f]{7}\)\z/, first)
    File.write(File.join(@source, 'SKILL.md'), 'changed')
    assert_predicate install.last, :success?
    refute_equal first, interface.fetch('display_name')
  end

  def test_preserves_existing_ui_metadata_and_invocation_policy
    write_custom_metadata
    assert_predicate install.last, :success?
    assert_match(/\AShaka /, interface.fetch('display_name'))
    assert_equal '#112233', interface.fetch('brand_color')
    assert_equal 'Use $shaka for my task.', interface.fetch('default_prompt')
    refute display.fetch('policy').fetch('allow_implicit_invocation')
  end

  def test_changed_display_metadata_is_rejected_on_reinstall_and_rollback
    assert_predicate install.last, :success?
    id = package_identity.fetch('package_id')
    File.write(File.join(@destination, 'agents/openai.yaml'), 'interface: {}')
    output, status = install
    refute_predicate status, :success?
    assert_includes output, 'Managed package content differs'
    output, status = run_installer('--skills-dir', @skills_dir, '--with-rct', '--rollback', id)
    refute_predicate status, :success?
    assert_includes output, 'Managed package content differs'
  end

  def test_read_only_source_ui_metadata_can_be_labeled_without_editing_source
    directory = read_only_custom_metadata
    install!
    assert_installed_mode 0o555, 'agents'
    assert_installed_mode 0o444, 'agents/openai.yaml'
    original = YAML.safe_load_file(File.join(directory, 'openai.yaml'))
    assert_equal 'Custom name', original.dig('interface', 'display_name')
  ensure
    restore_display_directories(directory)
  end

  def test_private_source_ui_metadata_keeps_its_permissions
    write_custom_metadata
    File.chmod(0o600, File.join(@source, 'agents/openai.yaml'))
    install!
    assert_installed_mode 0o600, 'agents/openai.yaml'
  end

  private

  def display = YAML.safe_load_file(File.join(@destination, 'agents/openai.yaml'))
  def interface = display.fetch('interface')

  def install!
    output, status = install
    assert_predicate status, :success?, output
  end

  def assert_installed_mode(expected, relative)
    assert_equal expected, File.stat(File.join(@destination, relative)).mode & 0o777
  end

  def read_only_custom_metadata
    write_custom_metadata
    directory = File.join(@source, 'agents')
    File.chmod(0o444, File.join(directory, 'openai.yaml'))
    File.chmod(0o555, directory)
    directory
  end

  def restore_display_directories(source)
    [source, File.join(@destination, 'agents')].compact.each do |path|
      File.chmod(0o755, path) if File.directory?(path)
    end
  end

  def write_custom_metadata
    FileUtils.mkdir_p(File.join(@source, 'agents'))
    File.write(File.join(@source, 'agents/openai.yaml'), <<~YAML)
      interface:
        display_name: "Custom name"
        short_description: "Custom workflow for verified pull requests"
        default_prompt: "Use $shaka for my task."
        brand_color: "#112233"
      policy:
        allow_implicit_invocation: false
    YAML
  end

  def commit_source
    root = File.join(@directory, 'source')
    git('init', '-q', root)
    git('-C', root, 'add', 'skills')
    git('-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-qm', 'fixture')
    git('-C', root, 'rev-parse', 'HEAD').strip
  end
end
