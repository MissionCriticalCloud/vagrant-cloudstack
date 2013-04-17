require "vagrant"

module VagrantPlugins
  module Cloudstack
    module Errors
      class VagrantCloudstackError < Vagrant::Errors::VagrantError
        error_namespace("vagrant_cloudstack.errors")
      end

      class FogError < VagrantCloudstackError
        error_key(:fog_error)
      end

      class InstanceReadyTimeout < VagrantCloudstackError
        error_key(:instance_ready_timeout)
      end

      class RsyncError < VagrantCloudstackError
        error_key(:rsync_error)
      end
    end
  end
end
