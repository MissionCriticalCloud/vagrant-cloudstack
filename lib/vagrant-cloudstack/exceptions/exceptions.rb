module VagrantPlugins
  module Cloudstack
    module Exceptions
      class IpNotFoundException < StandardError
      end
      class DuplicatePFRule < StandardError
      end
      class CloudstackResourceNotFound < StandardError
        def initialize(msg='Resource not found in cloudstack')
          super
        end
      end
    end
  end
end
