# frozen_string_literal: true

module Shaka
  # Whether a repository command file may be executed.
  #
  # Unix records that in the file mode, and File.executable? reads it. Windows Ruby
  # never reports an extensionless file as executable, even when Git stored mode
  # 100755 and the file begins with a shebang. Trust the shebang there.
  module ExecutableFile
    module_function

    def executable?(path)
      return true if File.executable?(path)
      return false unless windows?
      return false unless File.file?(path)

      shebang?(path)
    end

    def windows? = RUBY_PLATFORM.match?(/mswin|mingw/)

    def shebang?(path)
      File.open(path, 'rb') { |io| io.read(2) == '#!' }
    rescue SystemCallError
      false
    end

    # Install checks the owner bit Git stored. Windows checkout does not keep that bit.
    def mode_bit_or_shebang?(path)
      return true if File.stat(path).mode.anybits?(0o100)

      windows? && shebang?(path)
    rescue SystemCallError
      false
    end
  end
end
