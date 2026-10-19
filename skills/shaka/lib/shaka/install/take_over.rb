# frozen_string_literal: true

module Shaka
  module Install
    # Moves every host link from the registered checkout that owns them to this one, as one step.
    module TakeOver
      private

      # The checkout whose `shaka` links the host skills directories point at, other than this one.
      def owning_checkout(selected, skills_dir)
        directories = skills_dir ? [skills_dir] : host_directories
        owners = link_owners(directories) - [Checkout.new(selected).root]
        return Checkout.new(owners.first).tap(&:verify_directories) if owners.size == 1
        raise ArgumentError, no_owner_message(directories) if owners.empty?

        raise ArgumentError, "Several registered checkouts own Shaka links (#{owners.join(', ')}); " \
                             'a person must choose which to keep'
      end

      def host_directories = Official::HOSTS.values.map { |path| File.join(Dir.home, path) }

      def no_owner_message(directories)
        "No other registered checkout owns the Shaka links in #{directories.join(', ')}; " \
          'run bin/install without --take-over'
      end

      def link_owners(directories)
        directories.filter_map { |directory| link_owner(File.join(directory, 'shaka')) }.uniq
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

      # Both checkout locks in path order, so two opposite take-overs cannot wait on each other.
      def take_over
        with_locks(checkout_lock_directories) do
          @checkout.prepare(:install)
          targets = take_over_targets
          links = targets.map { |target| links_for(target, previous_source: @owner.root) }
          links.each { |entry| entry.check(@checkout.root) }
          move(targets, links)
          links.each(&:retire_aliases)
          verify(targets)
        end
      end

      def checkout_lock_directories = [@checkout.root, @owner.root].map { |root| File.join(root, '.git') }.sort

      # Holding every host lock until the records change keeps a rollback from undoing another install.
      def with_host_locks(links, &) = with_locks(links.map(&:lock_directory).uniq.sort, &)

      def with_locks(directories, &)
        return yield if directories.empty?

        with_lock(directories.first) { with_locks(directories.drop(1), &) }
      end

      def move(targets, links)
        recorded = identity(targets)
        record_ruby
        with_host_locks(links) { move_links(links) { @checkout.save(targets, recorded) } }
      end

      def take_over_targets
        owner = @owner.read_record or
          raise ArgumentError, "#{@owner.root} is no longer registered; run bin/install --take-over again"
        recorded = (@checkout.record&.fetch('targets') || []) + owner.fetch('targets')
        recorded.group_by { |target| target.fetch('directory') }.map do |directory, entries|
          { 'directory' => directory, 'names' => entries.flat_map { |target| target.fetch('names') }.uniq }
        end
      end

      # Until the new record is saved, a failure or an interrupt puts every host's links and the old record back.
      # The saved record is the commit point: after it, the take-over stands and nothing is undone.
      def move_links(links, &)
        previous = links.map(&:snapshot)
        before = new_record_bytes
        links.each { |entry| entry.switch_locked(@checkout.root) }
        retire_owner(&)
      rescue StandardError, SignalException
        raise unless new_record_bytes == before

        links.zip(previous).reverse_each { |entry, links_before| entry.restore_locked(links_before) }
        restore_owner_record
        warn "Take-over failed; links point at #{@owner.root} again"
        raise
      end

      def new_record_bytes
        path = File.join(@checkout.root, '.git', Checkout::RECORD)
        File.binread(path) if File.exist?(path)
      end

      # Renames the previous record so its checkout stops claiming the links; the checkout itself stays.
      def retire_owner
        stamp = Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
        retired = File.join(@owner.root, '.git', "shaka-install.retired-#{stamp}.json")
        raise ArgumentError, "Retired installation record already exists: #{retired}" if File.exist?(retired)

        @retired = retired
        File.rename(owner_record, retired)
        yield
        puts "Retired previous installation record: #{retired}"
      end

      def restore_owner_record
        return unless @retired && File.exist?(@retired) && !File.exist?(owner_record)

        File.rename(@retired, owner_record)
      rescue SystemCallError => e
        warn "Could not restore #{owner_record} from #{@retired}: #{e.message}"
      end

      def owner_record = File.join(@owner.root, '.git', Checkout::RECORD)
    end
  end
end
