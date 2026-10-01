# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'tmpdir'
require 'fileutils'
require 'open3'

class DocsNavigationTest < Minitest::Test
  def check(sidebar)
    Dir.mktmpdir do |root|
      File.write(File.join(root, 'expected-experience.md'), '# What to expect')
      File.write(File.join(root, 'sidebars.json'), JSON.generate(sidebar))
      Open3.capture3('ruby', File.expand_path('../bin/check-docs-navigation', __dir__), root)
    end
  end

  def test_new_page_missing_from_navigation_fails
    output, _, status = check('docsSidebar' => [])
    refute_predicate status, :success?
    assert_includes output, 'expected-experience'
  end

  def test_nested_document_is_reachable
    _, _, status = check('docsSidebar' => [{ 'type' => 'category', 'label' => 'Start',
                                             'items' => ['expected-experience'] }])
    assert_predicate status, :success?
  end

  def test_stale_document_entry_fails
    output, _, status = check('docsSidebar' => %w[expected-experience deleted-guide])
    refute_predicate status, :success?
    assert_includes output, 'deleted-guide'
  end
end
