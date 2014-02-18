module DevLoop
  class Watcher
    def self.run(repo_path, config)
      self.new(repo_path, config).run
    end

    attr_accessor :repo_path, :config, :log

    def initialize(repo_path, config, log = nil)
      @repo_path = repo_path
      @config = config
      @log = log || Logger.new(STDOUT)
    end

    def run
      threads = jcr_root_paths.map do |jcr_root_paths|
        Thread.new { watch_vault_package(jcr_root_paths) }
      end

      wait_for(threads)
    end

    def wait_for(threads)
      sleep 1 until threads.map {|thread| thread.join(1) }.all? {|result| result }
    end

    def watch_vault_package(jcr_root)
      if !File.exist?(jcr_root)
        log.warn "jcr_root points to non-existing directory: #{jcr_root}"
        return
      end

      fsevent = FSEvent.new
      options = {:latency => 0.1, :file_events => true}

      fsevent.watch jcr_root.to_s, options do |paths|
        paths.delete_if {|path| ignored?(path) }
        log.info "Detected change inside: #{paths.inspect}"

        paths.each do |path|
          if !File.exist?(path)
            log.info "#{path} no longer exists, syncing parent instead"
            path = File.dirname(path)
          end

          jcr_path = discover_jcr_path_from_file_in_vault_package(path)

          DevLoop::Sync.new(
            hostnames: hostnames,
            filesystem: path,
            jcr: jcr_path,
            log: log
          ).run
        end
      end

      log.info "Watching jcr_root at #{jcr_root} for changes..."
      fsevent.run
    end

    def jcr_root_paths
      config.fetch("jcrRootPaths", []).map {|jcr_root_path| Pathname(repo_path) + jcr_root_path }.map(&:to_s)
    end

    def hostnames
      config.fetch("instances")
    end

    # Return true if file should not trigger a sync
    def ignored?(file)
      return true if File.extname(file) == ".tmp"
      return true if file.match(/___$/)
      return false
    end

    # Find the root of the package to determine the path used for the filter
    def discover_jcr_path_from_file_in_vault_package(filesystem_path)
      possible_jcr_root = Pathname(filesystem_path).parent
      while !possible_jcr_root.root?
        break if possible_jcr_root.basename.to_s == "jcr_root"
        possible_jcr_root = possible_jcr_root.parent
      end

      filesystem_path.gsub(/^#{possible_jcr_root.to_s}/, "")
    end
  end
end