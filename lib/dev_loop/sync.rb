require 'uri'
require 'pathname'
require 'erb'
require 'tmpdir'
require 'logger'

module DevLoop
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
      
      @filesystem_path = if options.fetch(:filesystem).end_with?(".content.xml")
        Pathname(options.fetch(:filesystem)).parent.to_s
      else
        options.fetch(:filesystem)
      end
      
      @jcr_path = if options.fetch(:jcr).end_with?(".content.xml")
        Pathname(options.fetch(:jcr)).parent.to_s
      else
        options.fetch(:jcr)
      end
    rescue KeyError => e
      raise ArgumentError.new("#{e.message} (missing a hash argument)")
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
      FileUtils.mkdir_p(target_content)
      FileUtils.cp_r(filesystem_path, target_content)

      FileUtils.mkdir_p(vault_path)
      File.open(vault_path + "settings.xml", 'w') {|f| f.write(settings_template) }

      File.open(vault_path + "filter.xml", 'w') do |f| 
        paths = [jcr_path] # only do one path at the moment
        f.write(ERB.new(filter_template).result(binding))
      end

      sleep 0.1 until Dir.exist?(package_path)
    end

    def install_package
      threads = hostnames.map do |hostname|
        Thread.new do
          log.info "Installing package at #{package_path} to #{hostname.url_without_credentials}"
          command = "#{DevLoop.vlt_executable} --credentials #{hostname.credentials} -v import #{hostname.url_without_credentials} #{package_path} /"
          Terminal.new(log).execute_command(command)
        end
      end

      threads.each {|thread| thread.join } # wait for threads
    end

    def vault_path
      package_path + "META-INF/vault"
    end

    def target_content
      (jcr_root_path + jcr_path.gsub(/^\//, "")).parent
    end

    def package_path
      @package_path ||= Pathname(Dir.mktmpdir("vlt-sync"))
    end

    def jcr_root_path
      @jcr_root ||= package_path + "jcr_root"
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