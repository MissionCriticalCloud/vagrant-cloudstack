require "vagrant-cloudstack/config"

describe VagrantPlugins::Cloudstack::Config do
  let(:instance) { described_class.new }

  # Ensure tests are not affected by Cloudstack credential environment variables
  before :each do
    ENV.stub(:[] => nil)
  end

  describe "defaults" do
    subject do
      instance.tap do |o|
        o.finalize!
      end
    end

    its("host")                   { should be_nil }
    its("path")                   { should be_nil }
    its("port")                   { should be_nil }
    its("scheme")                 { should == "http" }
    its("api_key")                { should be_nil }
    its("secret_key")             { should be_nil }
    its("instance_ready_timeout") { should == 120 }
    its("domain_id")              { should be_nil }
    its("network_id")             { should be_nil }
    its("project_id")             { should be_nil }
    its("service_offering_id")    { should be_nil }
    its("template_id")            { should be_nil }
    its("zone_id")                { should be_nil }
    its("keypair_name")           { should be_nil }
  end

  describe "overriding defaults" do
    # I typically don't meta-program in tests, but this is a very
    # simple boilerplate test, so I cut corners here. It just sets
    # each of these attributes to "foo" in isolation, and reads the value
    # and asserts the proper result comes back out.
    [:api_key, :template_id, :zone_id, :instance_ready_timeout,
      :service_offering_id, :api_key,
      :secret_key, :network_id, :keypair_name].each do |attribute|

      it "should not default #{attribute} if overridden" do
        instance.send("#{attribute}=".to_sym, "foo")
        instance.finalize!
        instance.send(attribute).should == "foo"
      end
    end
  end

  describe "getting credentials from environment" do
    context "without Cloudstack credential environment variables" do
      subject do
        instance.tap do |o|
          o.finalize!
        end
      end

      its("api_key")    { should be_nil }
      its("secret_key") { should be_nil }
    end

  end

  describe "domain config" do
    let(:config_host)                   { "foo" }
    let(:config_path)                   { "foo" }
    let(:config_port)                   { "foo" }
    let(:config_scheme)                 { "foo" }
    let(:config_api_key)                { "foo" }
    let(:config_secret_key)             { "foo" }
    let(:config_instance_ready_timeout) { 11111 }
    let(:config_domain_id)              { "foo" }
    let(:config_network_id)             { "foo" }
    let(:config_project_id)             { "foo" }
    let(:config_service_offering_id)    { "foo" }
    let(:config_template_id)            { "foo" }
    let(:config_zone_id)                { "foo" }
    let(:config_keypair_name)           { "foo" }

    def set_test_values(instance)
      instance.host                   = config_host
      instance.path                   = config_path
      instance.port                   = config_port
      instance.scheme                 = config_scheme
      instance.api_key                = config_api_key
      instance.secret_key             = config_secret_key
      instance.instance_ready_timeout = config_instance_ready_timeout
      instance.domain_id              = config_domain_id
      instance.network_id             = config_network_id
      instance.project_id             = config_project_id
      instance.service_offering_id    = config_service_offering_id
      instance.template_id            = config_template_id
      instance.zone_id                = config_zone_id
      instance.keypair_name           = config_keypair_name
    end

    it "should raise an exception if not finalized" do
      expect { instance.get_domain_config("default") }.
        to raise_error
    end

    context "with no specific config set" do
      subject do
        # Set the values on the top-level object
        set_test_values(instance)

        # Finalize so we can get the domain config
        instance.finalize!

        # Get a lower level domain
        instance.get_domain_config("default")
      end

      its("host")                   { should == config_host }
      its("path")                   { should == config_path }
      its("port")                   { should == config_port }
      its("scheme")                 { should == config_scheme }
      its("api_key")                { should == config_api_key }
      its("secret_key")             { should == config_secret_key }
      its("instance_ready_timeout") { should == config_instance_ready_timeout }
      its("domain_id")              { should == config_domain_id }
      its("network_id")             { should == config_network_id }
      its("project_id")             { should == config_project_id }
      its("service_offering_id")    { should == config_service_offering_id }
      its("template_id")            { should == config_template_id }
      its("zone_id")                { should == config_zone_id }
      its("keypair_name")           { should == config_keypair_name }
    end

    context "with a specific config set" do
      let(:domain_name) { "hashi-domain" }

      subject do
        # Set the values on a specific domain
        instance.domain_config domain_name do |config|
          set_test_values(config)
        end

        # Finalize so we can get the domain config
        instance.finalize!

        # Get the domain
        instance.get_domain_config(domain_name)
      end

      its("host")                   { should == config_host }
      its("path")                   { should == config_path }
      its("port")                   { should == config_port }
      its("scheme")                 { should == config_scheme }
      its("api_key")                { should == config_api_key }
      its("secret_key")             { should == config_secret_key }
      its("instance_ready_timeout") { should == config_instance_ready_timeout }
      its("domain_id")              { should == config_domain_id }
      its("network_id")             { should == config_network_id }
      its("project_id")             { should == config_project_id }
      its("service_offering_id")    { should == config_service_offering_id }
      its("template_id")            { should == config_template_id }
      its("zone_id")                { should == config_zone_id }
      its("keypair_name")           { should == config_keypair_name }
    end

    describe "inheritance of parent config" do
      let(:domain_name) { "hashi-domain" }

      subject do
        # Set the values on a specific domain
        instance.domain_config domain_name do |config|
          config.template_id = "child"
        end

        # Set some top-level values
        instance.api_key     = "parent"
        instance.template_id = "parent"

        # Finalize and get the domain
        instance.finalize!
        instance.get_domain_config(domain_name)
      end

      its("api_key")     { should == "parent" }
      its("template_id") { should == "child" }
    end

    describe "shortcut configuration" do
      subject do
        # Use the shortcut configuration to set some values
        instance.domain_config "Domain1", :template_id => "child"
        instance.finalize!
        instance.get_domain_config("Domain1")
      end

      its("template_id") { should == "child" }
    end
  end
end
