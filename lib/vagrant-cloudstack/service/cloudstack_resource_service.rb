require 'vagrant-cloudstack/exceptions/exceptions'

module VagrantPlugins
  module Cloudstack
    module Service
      class CloudstackResourceService
        include VagrantPlugins::Cloudstack::Exceptions

        def initialize(cloudstack_compute, ui)
          @cloudstack_compute = cloudstack_compute
          @ui                 = ui
        end

        def sync_resource(resource, api_parameters = {})
          @resource_details = nil
          if resource.id.nil? and !(resource.name.nil? || resource.name.empty? )
            resource.id = name_to_id(resource.name, resource.kind, api_parameters)
          elsif resource.id
            resource.name = id_to_name(resource.id, resource.kind, api_parameters)
          end

          unless resource.is_id_undefined? || resource.is_name_undefined?
            resource.details = @resource_details
            @ui.detail("Syncronized resource: #{resource}")
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
          @resource_details = full_response.find {|type| type[resource_field] == resource_field_value } if full_response
          if @resource_details
            @resource_details['id']
          else
            raise CloudstackResourceNotFound.new("No UUID found for #{resource_type} with #{resource_field} '#{resource_field_value}'")
          end
        end

        def id_to_resourcefield(resource_id, resource_type, resource_field, options={})
          @ui.info("Fetching #{resource_field} for #{resource_type} with UUID '#{resource_id}'")
          options = options.merge({'id' => resource_id})
          begin
            full_response = translate_from_to(resource_type, options)
          rescue Fog::Compute::Cloudstack::BadRequest => e
            raise CloudstackResourceNotFound.new("No Name found for #{resource_type} with UUID '#{resource_id}', #{e.class.to_s} reports:\n #{e.message}")
          end
          @resource_details = full_response[0]
          @resource_details[resource_field]
        end

        def name_to_id(resource_name, resource_type, options={})
          resource_field = resource_type == 'public_ip_address' ? 'ipaddress' : 'name'
          resourcefield_to_id(resource_type, resource_field, resource_name, options)
        end

        def id_to_name(resource_id, resource_type, options={})
          resource_field = resource_type == 'public_ip_address' ? 'ipaddress' : 'name'
          id_to_resourcefield(resource_id, resource_type, resource_field, options)
        end
      end
    end
  end
end
