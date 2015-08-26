module VagrantPlugins
  module Cloudstack
    module Exceptions
      class IpNotFoundException < Exception
      end
      class DuplicatePFRule < Exception
      end
    end
  end
end
