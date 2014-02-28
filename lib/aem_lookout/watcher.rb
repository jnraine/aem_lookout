module AemLookout
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

      threads += sling_initial_content_paths.map do |sling_initial_content_path|
        Thread.new { watch_sling_initial_content(sling_initial_content_path) }
      end

      threads += command_configs.map do |command_config|
        Thread.new { watch_command_config(command_config) }
      end

      wait_for(threads)
    end

    def wait_for(threads)
      sleep 1 until Array(threads).map {|thread| thread.join(1) }.all? {|result| result }
    end

    def watch_vault_package(jcr_root)
      if !File.exist?(jcr_root)
        log.warn "jcr_root points to non-existing directory: #{jcr_root}"
        return
      end

      options = {:latency => 0.1, :file_events => true}
      fsevent = create_threaded_fsevent jcr_root.to_s, options do |paths|
        sync_vault_package_paths(paths)
      end

      log.info "Watching jcr_root at #{jcr_root} for changes..."
      fsevent.run
    end

    # Watch a given path with speified options and call action_block when a 
    # non-ignored path is modified. This also ensures that only one 
    # action_block is running at a time, killing any other running
    # blocks before starting a new one.
    def create_threaded_fsevent(watch_path, options, &action_block)
      fsevent = FSEvent.new
      running_jobs = Set.new

      fsevent.watch watch_path, options do |paths|
        paths.delete_if {|path| ignored?(path) }
        log.warn "Detected change inside: #{paths.inspect}" unless paths.empty?

        if running_jobs.length > 0
          log.warn "A job is currently running for this watcher, killing..."
          running_jobs.each {|thread| thread.kill }
        else
          log.warn "Phew, no running jobs: #{running_jobs}"
        end

        job = Thread.new do
          action_block.call(paths)
          Thread.exit
        end

        track_job_on_list(job, running_jobs)
      end

      fsevent
    end

    # Adds to running job list and removes from list when thread completes.
    def track_job_on_list(job, running_jobs)
      Thread.new do
        running_jobs << job
        log.warn "Waiting for #{job} to finish"
        wait_for(job)
        log.warn "#{job} job finished"
        running_jobs.delete(job)
        Thread.exit
      end
    end

    def sync_vault_package_paths(paths)
      paths.each do |path|
        if !File.exist?(path)
          log.warn "#{path} no longer exists, syncing parent instead"
          path = File.dirname(path)
        end

        jcr_path = discover_jcr_path_from_file_in_vault_package(path)

        AemLookout::Sync.new(
          hostnames: hostnames,
          filesystem: path,
          jcr: jcr_path,
          log: log
        ).run
      end
    end

    def watch_sling_initial_content(path)
      filesystem_path = path.fetch("filesystem")
      jcr_path = path.fetch("jcr")

      if !File.exist?(filesystem_path)
        log.warn "Filesystem path for Sling-Initial-Content points to non-existing directory: #{filesystem_path}"
        return
      end

      options = {:latency => 0.1, :file_events => true}
      fsevent = create_threaded_fsevent filesystem_path.to_s, options do |paths|
        begin
          handle_sling_initial_content_change(paths, filesystem_path, jcr_path)
        rescue LookoutError => e
          log.error "An error occurred while handling sling initial content change: #{e.message}"
        end
      end

      log.info "Watching Sling-Initial-Content at #{filesystem_path} for changes..."
      fsevent.run
    end

    def handle_sling_initial_content_change(paths, filesystem_path, jcr_path)
      paths.each do |path|
        if !File.exist?(path)
          log.info "#{path} no longer exists, syncing parent instead"
          path = File.dirname(path)
        end

        relative_jcr_path = path.gsub(/^.+#{filesystem_path}\//, "")

        AemLookout::Sync.new(
          hostnames: hostnames,
          filesystem: path,
          jcr: (Pathname(jcr_path) + relative_jcr_path).to_s,
          log: log,
          sling_initial_content: true
        ).run
      end
    end

    def watch_command_config(command_config)
      watch_path = command_config.fetch("watch")
      pwd = Pathname(repo_path) + command_config.fetch("pwd", "")
      command = command_config.fetch("command")

      options = {:latency => 1, :file_events => true}
      fsevent = create_threaded_fsevent watch_path, options do |paths|
        break if paths.empty?
        log.info "Running command"
        Terminal.new(log).execute_command("cd #{pwd} && #{command}")
      end

      log.info "Watching #{watch_path}, changes will run #{command.inspect}..."
      fsevent.run
    end

    def jcr_root_paths
      config.fetch("jcrRootPaths", []).map {|jcr_root_path| Pathname(repo_path) + jcr_root_path }.map(&:to_s)
    end

    def sling_initial_content_paths
      config.fetch("slingInitialContentPaths", []).map do |sling_initial_content_path|
        validate_sling_initial_content_path!(sling_initial_content_path)
        sling_initial_content_path
      end
    end

    # Something like this [{"watch" => "java-core/src/main/java", "pwd" => "java-core", "command" => "mvn install -P author-localhost"}]
    def command_configs
      config.fetch("commands", []).map do |command_config|
        validate_command_config!(command_config)
        command_config
      end
    end

    # Ensures required keys are present. This is ugly.
    def validate_command_config!(command_config)
      required_keys = ["watch", "command"]
      unless command_config.has_key?(required_keys.first) and command_config.has_key?(required_keys.last)
        raise "commands entry is malformed (requires these keys: #{required_keys.join(", ")}): #{command_config.inspect}"
      end
    end

    def validate_sling_initial_content_path!(path)
      unless path.has_key?("filesystem") and path.has_key?("jcr")
        raise "slingInitialContentPaths entry is malformed (requires \"filesystem\" and \"jcr\" entry): #{path.inspect}"
      end
    end

    def hostnames
      config.fetch("instances")
    end

    # Return true if file should not trigger a sync
    def ignored?(file)
      return true if File.extname(file) == ".tmp"
      return true if file.match(/___$/)
      return true if File.basename(file) == ".DS_Store"
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