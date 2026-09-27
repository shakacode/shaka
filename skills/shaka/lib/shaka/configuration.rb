# frozen_string_literal: true

require 'yaml'
require_relative 'configuration/paths'
require_relative 'repository_config'
require_relative 'trusted_config_source'
require_relative 'configuration/sources'

module Shaka
  # Supported access to repository configuration. Worktree and trusted-commit reads
  # are deliberately separate; callers cannot turn a missing trusted file into a
  # checkout fallback. RepositoryConfig and TrustedConfigSource remain focused internals.
  module Configuration
    extend Sources

    module_function

    def worktree(root:) = RepositoryConfig.load(root:)

    def trusted(root:, ref:, candidate_commands: true)
      TrustedConfigSource.load(root:, ref:, candidate_commands:)
    end

    def path(root, name)
      Paths.at(root, Paths.const_get(name))
    end

    def command_path(root, name)
      Paths.at(root, Paths::COMMANDS.fetch(name.to_s))
    end

    def command_file?(root, name)
      File.file?(command_path(root, name))
    end

    def contract_file?(root)
      File.file?(path(root, :CONTRACT))
    end

    def contract_entry?(root)
      target = path(root, :CONTRACT)
      File.lstat(target)
      true
    rescue Errno::ENOENT
      false
    end

    def contract_matches?(root, source)
      target = path(root, :CONTRACT)
      File.file?(target) && !File.symlink?(target) && File.read(target) == source
    end

    def contract_changed?(root, source)
      target = path(root, :CONTRACT)
      File.file?(target) && File.read(target) != source
    end

    def text(path, encoding: 'UTF-8')
      File.read(path, encoding:)
    end

    def generated_contract(marker:, data:)
      "# #{marker}\n#{YAML.dump(data)}"
    end

    def create_file(path, content, mode:)
      File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
        yield if block_given?
        file.write(content)
        file.chmod(mode)
      end
    end

    def replace_file(path, content, mode:)
      tmp = "#{path}.migrate-#{Process.pid}"
      create_file(tmp, content, mode:)
      File.rename(tmp, path)
    ensure
      File.delete(tmp) if tmp && File.file?(tmp)
    end
  end
end
