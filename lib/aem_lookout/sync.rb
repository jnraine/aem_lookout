require 'uri'
require 'pathname'
require 'erb'
require 'tmpdir'
require 'logger'

module AemLookout
  class Sync
    class Hostname
      attr_accessor :url

      def initialize(hostname)
        @url = URI.parse(hostname)
      end

      def url_without_credentials
        "#{url.scheme}://#{url.host}:#{url.port}/crx/-/jcr:root"
      end

      def credentials
        "#{url.user}:#{url.password}"
      end
    end

    def self.run(options)
      self.new(options).run
    end

    attr_accessor :log, :hostnames, :filesystem_path, :jcr_path

    def initialize(options)
      default_log = Logger.new(options.fetch(:output, STDOUT))
      @log = options.fetch(:log, default_log)
      @hostnames = options.fetch(:hostnames).map {|hostname| Hostname.new(hostname) }
      @sling_initial_content = options.fetch(:sling_initial_content, false)
      @filesystem_path = options.fetch(:filesystem)
      @jcr_path = options.fetch(:jcr)
    rescue KeyError => e
      raise ArgumentError.new("#{e.message} (missing a hash argument)")
    end

    # Locals on the local filesystem to copy into the package
    def content_paths
      if @content_paths.nil?
        paths = if filesystem_path.end_with?(".content.xml")
          Pathname(filesystem_path).parent.to_s
        elsif sling_initial_content? and filesystem_path.end_with?(".json")
          [filesystem_path, filesystem_path.gsub(/.json$/, "")].delete_if { |path| !File.exist?(path) }
        else
          filesystem_path
        end

        @content_paths = Array(paths)
      end

      @content_paths
    end

    # Paths in the package to install into the JCR
    def filter_paths
      if @filter_paths.nil?
        paths = if jcr_path.end_with?(".content.xml")
          Pathname(jcr_path).parent.to_s
        elsif sling_initial_content? and jcr_path.end_with?(".json")
          jcr_path.gsub(/.json$/, "")
        else
          jcr_path
        end

        @filter_paths = Array(paths)
      end

      @filter_paths
    end

    def run
      start_timer
      build_package
      install_package
      log_elapsed_time
    end

    def start_timer
      @start_time = Time.now
    end

    def log_elapsed_time
      elapsed_time = (Time.now.to_f - @start_time.to_f).round(2)
      log.info "Elapsed time: #{elapsed_time} seconds"
    end

    def build_package
      copy_content_to_package
      create_settings
      create_filter
      SlingInitialContentConverter.convert_package(package_path) if sling_initial_content?
      sleep 0.1 # just in case
    end

    def copy_content_to_package
      FileUtils.mkdir_p(target_content_path_root)
      content_paths.each do |content_path|
        log.info "Copying content from #{content_path} to target content path root"
        FileUtils.cp_r(content_path, target_content_path_root)
      end
    end

    def create_settings
      FileUtils.mkdir_p(vault_config_path)
      File.open(vault_config_path + "settings.xml", 'w') {|f| f.write(settings_template) }
    end

    def create_filter
      File.open(vault_config_path + "filter.xml", 'w') do |f|
        paths = filter_paths
        f.write(ERB.new(filter_template).result(binding))
      end
    end

    def sling_initial_content_filter_paths_for(jcr_path)
      
    end

    def install_package
      threads = hostnames.map do |hostname|
        Thread.new do
          log.info "Installing package at #{package_path} to #{hostname.url_without_credentials}"
          command = "#{AemLookout.vlt_executable} --credentials #{hostname.credentials} -v import #{hostname.url_without_credentials} #{package_path} /"
          Terminal.new(log).execute_command(command)
        end
      end

      threads.each {|thread| thread.join } # wait for threads
    end

    def vault_config_path
      package_path + "META-INF/vault"
    end

    def target_content_path_root
      (jcr_root_path + jcr_path.gsub(/^\//, "")).parent
    end

    def package_path
      @package_path ||= Pathname(Dir.mktmpdir("vlt-sync"))
    end

    def jcr_root_path
      @jcr_root ||= package_path + "jcr_root"
    end

    def sling_initial_content?
      @sling_initial_content
    end

    def settings_template
      <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<vault version="0.1">
  <ignore name=".svn"/>
  <ignore name=".gitignore"/>
  <ignore name=".DS_Store"/>
</vault>
      EOF
    end

    def filter_template
      <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<workspaceFilter vesion="0.1">
<% paths.each do |path| %>  <filter root="<%= path %>" mode="replace"/>\n<% end %>
</workspaceFilter>
      EOF
    end
  end
end