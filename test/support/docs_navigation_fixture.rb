# frozen_string_literal: true

require_relative '../test_helper'
require 'json'
require 'tmpdir'
require 'fileutils'
require 'open3'

module DocsNavigationFixture
  # Repository-local variables reported by git rev-parse --local-env-vars; keep global config.
  GIT_ROUTING = %w[GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
                   GIT_OBJECT_DIRECTORY GIT_DIR GIT_WORK_TREE GIT_IMPLICIT_WORK_TREE GIT_GRAFT_FILE
                   GIT_INDEX_FILE GIT_NO_REPLACE_OBJECTS GIT_REPLACE_REF_BASE GIT_PREFIX GIT_SHALLOW_FILE
                   GIT_COMMON_DIR].freeze

  def check(sidebar, page = '# What to expect', files = {})
    saved = GIT_ROUTING.to_h { |name| [name, ENV.delete(name)] }
    Dir.mktmpdir do |repository|
      prepare_fixture(repository, sidebar, page, files)
      yield repository if block_given?
      Open3.capture3('ruby', File.expand_path('../../bin/check-docs-navigation', __dir__),
                     File.join(repository, 'docs'))
    end
  ensure
    saved.each { |name, value| ENV[name] = value }
  end

  def create_symlink(target, path)
    File.symlink(target, path)
  rescue NotImplementedError, Errno::EPERM, Errno::EACCES
    skip 'Real symlink creation is unavailable'
  end

  def prepare_fixture(repository, sidebar, page, files)
    tree = { 'docs/expected-experience.md' => page, 'docs/sidebars.json' => JSON.generate(sidebar) }
    tree.merge(files).each do |path, text|
      FileUtils.mkdir_p(File.dirname(File.join(repository, path)))
      File.write(File.join(repository, path), text)
    end
    system('git', 'init', '-q', repository, exception: true)
    raise 'Fixture Git directory was not created' unless File.directory?(File.join(repository, '.git'))
  end
  SETTINGS = <<~MARKDOWN
    # Settings
    ## Add a second reviewer
    ## `review.ci_review_wait`
    ## Examples
    ## Examples
    ### See [the guide](#examples) first
    <a id="opening_check"></a>
    ```text
    ## Not a heading
    ```
  MARKDOWN

  def check_links(page, files = {})
    check({ 'docsSidebar' => %w[expected-experience settings] }, page, { 'docs/settings.md' => SETTINGS }.merge(files))
  end
end
