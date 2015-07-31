require 'spec_helper'
require 'vagrant-cloudstack/model/cloudstack_resource'

include VagrantPlugins::Cloudstack::Model

describe CloudstackResource do
  context 'when all attribtues are defined' do
    let(:resource) { CloudstackResource.new('id', 'name', 'kind') }

    describe '#to_s' do
      it 'prints the resource with all attributes' do
        expect(resource.to_s).to be_eql 'kind - id:name'
      end
    end

    describe '#is_undefined?' do
      it { expect(resource.is_undefined?).to be_eql false }
    end

    describe '#is_id_undefined?' do
      it { expect(resource.is_id_undefined?).to be_eql false }
    end

    describe '#is_name_undefined?' do
      it { expect(resource.is_name_undefined?).to be_eql false }
    end
  end

  context 'when kind is not defined' do
    describe '#new' do
      it 'raises an error when kind is nil' do
        expect { CloudstackResource.new('id', 'name', nil) }.to raise_error('Resource must have a kind')
      end

      it 'raises an error when kind is empty' do
        expect { CloudstackResource.new('id', 'name', '') }.to raise_error('Resource must have a kind')
      end
    end
  end

  describe '#is_undefined?' do
    it { expect(CloudstackResource.new('', '', 'kind').is_undefined?).to be_eql true }
    it { expect(CloudstackResource.new(nil, '', 'kind').is_undefined?).to be_eql true }
    it { expect(CloudstackResource.new('', nil, 'kind').is_undefined?).to be_eql true }
    it { expect(CloudstackResource.new(nil, nil, 'kind').is_undefined?).to be_eql true }
    it { expect(CloudstackResource.new('id', nil, 'kind').is_undefined?).to be_eql false }
    it { expect(CloudstackResource.new(nil, 'name', 'kind').is_undefined?).to be_eql false }
    it { expect(CloudstackResource.new('id', '', 'kind').is_undefined?).to be_eql false }
    it { expect(CloudstackResource.new('', 'name', 'kind').is_undefined?).to be_eql false }
  end

  describe '#is_id_undefined?' do
    it { expect(CloudstackResource.new('', 'name', 'kind').is_id_undefined?).to be_eql true }
    it { expect(CloudstackResource.new(nil, 'name', 'kind').is_id_undefined?).to be_eql true }
    it { expect(CloudstackResource.new('', '', 'kind').is_id_undefined?).to be_eql true }
    it { expect(CloudstackResource.new(nil, '', 'kind').is_id_undefined?).to be_eql true }
    it { expect(CloudstackResource.new('', nil, 'kind').is_id_undefined?).to be_eql true }
    it { expect(CloudstackResource.new(nil, nil, 'kind').is_id_undefined?).to be_eql true }
    it { expect(CloudstackResource.new('id', nil, 'kind').is_id_undefined?).to be_eql false }
    it { expect(CloudstackResource.new('id', '', 'kind').is_id_undefined?).to be_eql false }
  end

  describe '#is_name_undefined?' do
    it { expect(CloudstackResource.new('id', '', 'kind').is_name_undefined?).to be_eql true }
    it { expect(CloudstackResource.new('id', nil, 'kind').is_name_undefined?).to be_eql true }
    it { expect(CloudstackResource.new('', '', 'kind').is_name_undefined?).to be_eql true }
    it { expect(CloudstackResource.new(nil, '', 'kind').is_name_undefined?).to be_eql true }
    it { expect(CloudstackResource.new('', nil, 'kind').is_name_undefined?).to be_eql true }
    it { expect(CloudstackResource.new(nil, nil, 'kind').is_name_undefined?).to be_eql true }
    it { expect(CloudstackResource.new(nil, 'name', 'kind').is_name_undefined?).to be_eql false }
    it { expect(CloudstackResource.new('', 'name', 'kind').is_name_undefined?).to be_eql false }
  end
end
