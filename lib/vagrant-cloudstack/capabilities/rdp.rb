module VagrantPlugins
  module Cloudstack
    module Cap
      class Rdp
        def self.rdp_info(machine)
          env = machine.action('read_rdp_info')
          env[:machine_rdp_info]
        end
      end
    end
  end
end
