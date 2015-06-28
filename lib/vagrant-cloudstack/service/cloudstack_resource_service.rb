module VagrantPlugins
  module Cloudstack
    module Service
      class CloudstackResourceService
        def initialize(cloudstack_compute, ui)
          @cloudstack_compute = cloudstack_compute
          @ui                 = ui
        end

        def sync_resource(resource, api_parameters = {})
          @ui.detail("Syncronizing resource: #{resource}")
          if resource.id.nil? and resource.name
            resource.id = name_to_id(resource.name, resource.kind, api_parameters)
          elsif resource.id
            resource.name = id_to_name(resource.id, resource.kind, api_parameters)
          end
        end

        private

        def translate_from_to(resource_type, options)
          if resource_type == 'public_ip_address'
            pluralised_type = 'public_ip_addresses'
          else
            pluralised_type = "#{resource_type}s"
          end

          full_response = @cloudstack_compute.send("list_#{pluralised_type}".to_sym, options)
          full_response["list#{pluralised_type.tr('_', '')}response"][resource_type.tr('_', '')]
        end

        def resourcefield_to_id(resource_type, resource_field, resource_field_value, options={})
          @ui.info("Fetching UUID for #{resource_type} with #{resource_field} '#{resource_field_value}'")
          full_response = translate_from_to(resource_type, options)
          result        = full_response.find {|type| type[resource_field] == resource_field_value }
          result['id']
        end

        def id_to_resourcefield(resource_id, resource_type, resource_field, options={})
          @ui.info("Fetching #{resource_field} for #{resource_type} with UUID '#{resource_id}'")
          options = options.merge({'id' => resource_id})
          full_response = translate_from_to(resource_type, options)
          full_response[0][resource_field]
        end

        def name_to_id(resource_name, resource_type, options={})
          resourcefield_to_id(resource_type, 'name', resource_name, options)
        end

        def id_to_name(resource_id, resource_type, options={})
          id_to_resourcefield(resource_id, resource_type, 'name', options)
        end
      end
    end
  end
end
