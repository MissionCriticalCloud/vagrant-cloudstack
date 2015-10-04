module VagrantPlugins
  module Cloudstack
    module Service
      class BaseService
        def initialize(cloudstack_compute, ui)
          @cloudstack_compute = cloudstack_compute
          @ui                 = ui
        end
      end
    end
  end
end
