require 'spec_helper'
require 'vagrant-cloudstack/model/cloudstack_resource'
require 'vagrant-cloudstack/service/cloudstack_resource_service'

include VagrantPlugins::Cloudstack::Model
include VagrantPlugins::Cloudstack::Service

describe CloudstackResourceService do
  let(:cloudstack_compute) { double('Fog::Compute::Cloudstack') }
  let(:ui) { double('Vagrant::UI') }
  let(:service) { CloudstackResourceService.new(cloudstack_compute, ui) }

  before do
    response = {
      'listkindsresponse' => {
        'kind' => [{ 'id' => 'resource id', 'name' => 'resource name' }]
      }
    }
    allow(cloudstack_compute).to receive(:send).with(:list_kinds, { 'id' => 'resource id' }).and_return(response)
    allow(cloudstack_compute).to receive(:send).with(:list_kinds, {}).and_return(response)

    allow(ui).to receive(:detail)
    allow(ui).to receive(:info)
  end

  describe '#sync_resource' do
    it 'retrives the missing name' do
      resource = CloudstackResource.new('resource id', nil, 'kind')
      expect(service.sync_resource(resource)).to be_eql 'resource name'
    end

    it 'retrives the missing id' do
      resource = CloudstackResource.new(nil, 'resource name', 'kind')
      expect(service.sync_resource(resource)).to be_eql 'resource id'
    end
  end
end
