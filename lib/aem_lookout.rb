require 'vlt_wrapper'

require 'aem_lookout/version'
require 'aem_lookout/lookout_error'
require 'aem_lookout/sling_initial_content_converter'
require 'aem_lookout/sync'
require 'aem_lookout/terminal'
require 'aem_lookout/watcher'


module AemLookout
  def vlt_executable
    VltWrapper.executable
  end

  extend self
end