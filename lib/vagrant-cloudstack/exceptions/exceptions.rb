module VagrantPlugins
  module Cloudstack
    module Exceptions
      class NoIpProvidedException < Exception
      end
      class DuplicatePFRule < Exception
      end
      class ApiCommandFailed < Exception
      end
    end
  end
end
