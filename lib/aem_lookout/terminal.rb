require 'open3'

# A helper class for running terminal commands in the background while 
# streaming to a Ruby logger.
module AemLookout
  class Terminal
    attr_reader :log

    def initialize(log = Logger.new(STDOUT))
      @log = log
    end

    def execute_command(command)
      Open3.popen3(command) do |stdin, stdout, stderr, thread|
        flush(stdout: stdout, stderr: stderr) until !thread.alive?
        flush(stdout: stdout, stderr: stderr)
      end
    end

    def flush(options = {})
      stdout_thread = stream_to_log(options.fetch(:stdout))
      stderr_thread = stream_to_log(options.fetch(:stderr), error: true)
      sleep 0.1 until !stdout_thread.alive? and !stdout_thread.alive?
    end

    def stream_to_log(io, options = {})
      options = options.merge({error: false})
      thread = Thread.new do
        while message = io.gets
          if options.fetch(:error)
            log.error message.chomp
          else
            log.info message.chomp
          end

          sleep 0.01 # to ensure line isn't still being written to
        end
      end
    end
  end
end