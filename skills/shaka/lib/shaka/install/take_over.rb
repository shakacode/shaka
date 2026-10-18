# frozen_string_literal: true

module Shaka
  module Install
    # Moves every host link from the registered checkout that owns them to this one, as one step.
    module TakeOver
      private

      # The checkout whose `shaka` links the host skills directories point at, other than this one.
      def owning_checkout(selected, skills_dir)
        directories = skills_dir ? [skills_dir] : host_directories
        owners = directories.filter_map { |directory| link_owner(File.join(directory, 'shaka')) }.uniq
        owners -= [Checkout.new(selected).root]
        return Checkout.new(owners.first) if owners.size == 1
        raise ArgumentError, no_owner_message(directories) if owners.empty?

        raise ArgumentError, "Several registered checkouts own Shaka links (#{owners.join(', ')}); " \
                             'a person must choose which to keep'
      end

      def host_directories = Official::HOSTS.values.map { |path| File.join(Dir.home, path) }

      def no_owner_message(directories)
        "No other registered checkout owns the Shaka links in #{directories.join(', ')}; " \
          'run bin/install without --take-over'
      end

      def link_owner(link)
        return unless File.symlink?(link)

        owner = File.dirname(File.realpath(link), 2)
        owner if File.file?(File.join(owner, '.git', Checkout::RECORD))
      rescue Errno::ENOENT, Errno::ELOOP
        nil
      end

      # A take-over clones the repository and branch the previous checkout follows unless told otherwise.
      def source_options(options)
        record = @owner&.read_record || {}
        { repository: options[:repository] || record['repository'], branch: options[:branch] || record['branch'] }
      end

      def take_over
        with_lock(File.join(@owner.root, '.git')) do
          @checkout.prepare(:install)
          targets = take_over_targets
          links = targets.map { |target| links_for(target, previous_source: @owner.root) }
          links.each { |entry| entry.check(@checkout.root) }
          move(targets, links)
          verify(targets)
        end
      end

      def move(targets, links)
        recorded = identity(targets)
        record_ruby
        move_links(links) { retire_owner { @checkout.save(targets, recorded) } }
        links.each(&:retire_aliases)
      end

      def take_over_targets
        recorded = (@checkout.record&.fetch('targets') || []) + @owner.read_record.fetch('targets')
        recorded.group_by { |target| target.fetch('directory') }.map do |directory, entries|
          { 'directory' => directory, 'names' => entries.flat_map { |target| target.fetch('names') }.uniq }
        end
      end

      # A failure in any host, or in the record changes, puts every host's links back.
      def move_links(links)
        previous = []
        links.each_with_index { |entry, index| previous[index] = entry.switch_all(@checkout.root) }
        yield
      rescue StandardError
        previous.each_with_index.reverse_each { |links_before, index| links[index].restore_all(links_before) }
        warn "Take-over failed; links point at #{@owner.root} again" unless previous.empty?
        raise
      end

      # Renames the previous record so its checkout stops claiming the links; the checkout itself stays.
      def retire_owner(&)
        record = File.join(@owner.root, '.git', Checkout::RECORD)
        stamp = Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
        retired = File.join(@owner.root, '.git', "shaka-install.retired-#{stamp}.json")
        raise ArgumentError, "Retired installation record already exists: #{retired}" if File.exist?(retired)

        File.rename(record, retired)
        restore_record_on_failure(retired, record, &)
        puts "Retired previous installation record: #{retired}"
      end

      def restore_record_on_failure(retired, record)
        yield
      rescue StandardError
        File.rename(retired, record)
        raise
      end
    end
  end
end
