RSpec::Matchers.define :be_a_resource do |id, name, kind|
  match do |actual|
    actual.is_a?(VagrantPlugins::Cloudstack::Model::CloudstackResource) &&
      actual.id == id && actual.name == name && actual.kind == kind
  end
end
