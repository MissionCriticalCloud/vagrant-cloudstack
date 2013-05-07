require "vagrant-cloudstack/util/timer"

module VagrantPlugins
  module Cloudstack
    module Action
      # This is the same as the builtin provision except it times the
      # provisioner runs.
      class TimedProvision < Vagrant::Action::Builtin::Provision
        def run_provisioner(env, pname, p)
          timer = Util::Timer.time do
            super
          end

          env[:metrics] ||= {}
          env[:metrics]["provisioner_times"] ||= []
          env[:metrics]["provisioner_times"] << [p.class.to_s, timer]
        end
      end
    end
  end
end
