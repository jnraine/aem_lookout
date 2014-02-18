require 'vlt_wrapper'

require 'dev_loop/version'
require 'dev_loop/sling_initial_content_converter'
require 'dev_loop/sync'
require 'dev_loop/terminal'
require 'dev_loop/watcher'


module DevLoop
  def vlt_executable
    VltWrapper.executable
  end

  extend self
end