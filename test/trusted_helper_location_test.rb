# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'fileutils'
require 'json'

class TrustedHelperLocationTest < Minitest::Test
  include RepositoryConfigTestHelpers

  SKILL = File.expand_path('../skills/shaka', __dir__)

  def test_trusted_read_refuses_a_helper_inside_the_checkout
    with_repository do |root|
      helper = install_skill(File.join(root, 'skills'))
      commit(root)

      error, status = trusted_check(helper, root)

      refute_predicate status, :success?
      assert_includes error, 'resolves inside the checkout'
    end
  end

  def test_trusted_read_refuses_a_helper_reached_through_a_symlinked_root
    with_repository do |root|
      helper = install_skill(File.join(root, 'skills'))
      commit(root)
      with_symlink(root) do |link|
        error, status = trusted_check(helper, link)

        refute_predicate status, :success?
        assert_includes error, 'resolves inside the checkout'
      end
    end
  end

  def test_trusted_read_refuses_an_installed_skill_link_into_the_checkout
    with_repository do |root|
      install_skill(File.join(root, 'skills'))
      commit(root)
      with_symlink(File.join(root, 'skills/shaka')) do |skill|
        error, status = trusted_check(File.join(skill, 'scripts/shaka'), root)

        refute_predicate status, :success?
        assert_includes error, 'resolves inside the checkout'
      end
    end
  end

  def test_local_review_refuses_a_helper_inside_the_checkout
    with_repository do |root|
      helper = install_skill(File.join(root, 'skills'))
      commit(root)
      head = `git -C #{root} rev-parse HEAD`.strip
      output, _error, status = Open3.capture3(helper, 'review', 'run', '--root', root, '--head', head,
                                              '--base', head, '--reviewer', 'openai/codex')

      refute_predicate status, :success?
      assert_includes JSON.parse(output).fetch('reason'), 'resolves inside the checkout'
    end
  end

  def test_trusted_read_accepts_a_helper_in_a_sibling_with_a_shared_prefix
    Dir.mktmpdir('shaka-parent') do |parent|
      with_repository do |source|
        root = File.join(parent, 'repo')
        FileUtils.cp_r(source, root)
        commit(root)
        helper = install_skill(File.join(parent, 'repo-tools'))

        error, status = trusted_check(helper, root)

        assert_predicate status, :success?, error
      end
    end
  end

  def test_local_check_grants_no_policy_and_still_runs_inside_the_checkout
    with_repository do |root|
      helper = install_skill(File.join(root, 'skills'))

      _output, error, status = Open3.capture3(helper, 'seam', 'check', '--root', root, '--local')

      assert_predicate status, :success?, error
    end
  end

  private

  def with_symlink(target)
    Dir.mktmpdir('shaka-link') do |links|
      link = File.join(links, 'checkout')
      File.symlink(target, link)
      yield link
    end
  end

  def trusted_check(helper, root)
    _output, error, status = Open3.capture3(helper, 'seam', 'check', '--root', root, '--ref', 'HEAD')
    [error, status]
  end

  def install_skill(directory)
    FileUtils.mkdir_p(directory)
    FileUtils.cp_r(SKILL, directory)
    File.join(directory, 'shaka/scripts/shaka')
  end

  def commit(root)
    system('git', '-C', root, 'init', '--quiet', exception: true)
    system('git', '-C', root, 'add', '.', exception: true)
    system('git', '-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
           'commit', '--quiet', '-m', 'trusted', exception: true)
  end
end
