require "spec_helper"
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

    its("host")                   { should be_nil  }
    its("path")                   { should be_nil  }
    its("port")                   { should be_nil  }
    its("scheme")                 { should be_nil  }
    its("api_key")                { should be_nil  }
    its("secret_key")             { should be_nil  }
    its("instance_ready_timeout") { should == 120  }
    its("domain_id")              { should be_nil  }
    its("network_id")             { should be_nil  }
    its("project_id")             { should be_nil  }
    its("service_offering_id")    { should be_nil  }
    its("disk_offering_id")       { should be_nil  }
    its("template_id")            { should be_nil  }
    its("zone_id")                { should be_nil  }
    its("keypair")                { should be_nil  }
    its("static_nat")             { should == []   }
    its("pf_ip_address_id")       { should be_nil  }
    its("pf_ip_address")          { should be_nil  }
    its("pf_public_port")         { should be_nil  }
    its("pf_private_port")        { should be_nil  }
    its("pf_open_firewall")       { should == true }
    its("pf_trusted_networks")    { should be_nil  }
    its("port_forwarding_rules")  { should == []   }
    its("firewall_rules")         { should == []   }
    its("security_group_ids")     { should == []   }
    its("display_name")           { should be_nil  }
    its("group")                  { should be_nil  }
    its("security_group_names")   { should == []   }
    its("security_groups")        { should == []   }
    its("user_data")              { should be_nil  }
    its("ssh_key")                { should be_nil  }
    its("ssh_user")               { should be_nil  }
    its("vm_user")                { should be_nil  }
    its("vm_password")            { should be_nil  }
    its("private_ip_address")     { should be_nil  }
    its("expunge_on_destroy")     { should == false  }
  end

  describe "getting credentials from environment" do
    context "without CloudStack credential environment variables" do
      subject do
        instance.tap do |o|
          o.finalize!
        end
      end

      its("api_key")    { should be_nil }
      its("secret_key") { should be_nil }
    end

    context "with CloudStack credential variables" do
      before :each do
        ENV.stub(:[]).with("CLOUDSTACK_API_KEY").and_return("api_key")
        ENV.stub(:[]).with("CLOUDSTACK_SECRET_KEY").and_return("secret_key")
      end

      subject do
        instance.tap do |o|
          o.finalize!
        end
      end

      its("api_key")    { should == "api_key" }
      its("secret_key") { should == "secret_key" }
    end
  end

  describe "overriding defaults" do
    # I typically don't meta-program in tests, but this is a very
    # simple boilerplate test, so I cut corners here. It just sets
    # each of these attributes to "foo" in isolation, and reads the value
    # and asserts the proper result comes back out.
    [:api_key, :template_id, :zone_id, :instance_ready_timeout,
      :service_offering_id, :disk_offering_id, :api_key,
      :secret_key, :network_id, :user_data].each do |attribute|

      it "should not default #{attribute} if overridden" do
        instance.send("#{attribute}=".to_sym, "foo")
        instance.finalize!
        instance.send(attribute).should == "foo"
      end

    end

    it 'should not default pf_open_firewall if overridden' do
      instance.pf_open_firewall = false
      instance.finalize!

      instance.pf_open_firewall.should == false
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
    let(:config_disk_offering_id)       { "foo" }
    let(:config_template_id)            { "foo" }
    let(:config_zone_id)                { "foo" }
    let(:config_keypair)                { "foo" }
    let(:config_static_nat)             { [{:foo => "bar"}, {:bar => "foo"}] }
    let(:config_pf_ip_address_id)       { "foo" }
    let(:config_pf_ip_address)          { "foo" }
    let(:config_pf_public_port)         { "foo" }
    let(:config_pf_private_port)        { "foo" }
    let(:config_pf_open_firewall)       { false }
    let(:config_pf_trusted_networks)    { "foo" }
    let(:config_port_forwarding_rules)  { [{:foo => "bar"}, {:bar => "foo"}] }
    let(:config_firewall_rules)         { [{:foo => "bar"}, {:bar => "foo"}] }
    let(:config_security_group_ids)     { ["foo", "bar"] }
    let(:config_display_name)           { "foo" }
    let(:config_group)                  { "foo" }
    let(:config_security_group_names)   { ["foo", "bar"] }
    let(:config_security_groups)        { [{:foo => "bar"}, {:bar => "foo"}] }
    let(:config_ssh_key)                { "./foo.pem" }
    let(:config_ssh_user)               { "foo" }
    let(:config_vm_user)                { "foo" }
    let(:config_vm_password)            { "foo" }
    let(:config_private_ip_address)     { "foo" }
    let(:config_expunge_on_destroy)     { "foo" }

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
      instance.disk_offering_id       = config_disk_offering_id
      instance.template_id            = config_template_id
      instance.zone_id                = config_zone_id
      instance.keypair                = config_keypair
      instance.static_nat             = config_static_nat
      instance.pf_ip_address_id       = config_pf_ip_address_id
      instance.pf_ip_address          = config_pf_ip_address
      instance.pf_public_port         = config_pf_public_port
      instance.pf_private_port        = config_pf_private_port
      instance.pf_open_firewall       = config_pf_open_firewall
      instance.pf_trusted_networks    = config_pf_trusted_networks
      instance.port_forwarding_rules  = config_port_forwarding_rules
      instance.firewall_rules         = config_firewall_rules
      instance.security_group_ids     = config_security_group_ids
      instance.display_name           = config_display_name
      instance.group                  = config_group
      instance.security_group_names   = config_security_group_names
      instance.security_groups        = config_security_groups
      instance.ssh_key                = config_ssh_key
      instance.ssh_user               = config_ssh_user
      instance.vm_user                = config_vm_user
      instance.vm_password            = config_vm_password
      instance.private_ip_address     = config_private_ip_address
      instance.expunge_on_destroy     = config_expunge_on_destroy
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
      its("disk_offering_id")       { should == config_disk_offering_id }
      its("template_id")            { should == config_template_id }
      its("zone_id")                { should == config_zone_id }
      its("keypair")                { should == config_keypair }
      its("static_nat")             { should == config_static_nat }
      its("pf_ip_address_id")       { should == config_pf_ip_address_id }
      its("pf_ip_address")          { should == config_pf_ip_address }
      its("pf_public_port")         { should == config_pf_public_port }
      its("pf_private_port")        { should == config_pf_private_port }
      its("pf_trusted_networks")    { should == config_pf_trusted_networks}
      its("pf_open_firewall")       { should == config_pf_open_firewall }
      its("port_forwarding_rules")  { should == config_port_forwarding_rules }
      its("firewall_rules")         { should == config_firewall_rules }
      its("security_group_ids")     { should == config_security_group_ids }
      its("display_name")           { should == config_display_name }
      its("group")                  { should == config_group }
      its("security_group_names")   { should == config_security_group_names }
      its("security_groups")        { should == config_security_groups }
      its("ssh_key")                { should == config_ssh_key }
      its("ssh_user")               { should == config_ssh_user }
      its("vm_user")                { should == config_vm_user }
      its("vm_password")            { should == config_vm_password }
      its("private_ip_address")     { should == config_private_ip_address }
      its("expunge_on_destroy")     { should == config_expunge_on_destroy }
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
      its("disk_offering_id")       { should == config_disk_offering_id }
      its("template_id")            { should == config_template_id }
      its("zone_id")                { should == config_zone_id }
      its("keypair")                { should == config_keypair }
      its("static_nat")             { should == config_static_nat }
      its("pf_ip_address_id")       { should == config_pf_ip_address_id }
      its("pf_ip_address")          { should == config_pf_ip_address }
      its("pf_public_port")         { should == config_pf_public_port }
      its("pf_private_port")        { should == config_pf_private_port }
      its("pf_open_firewall")       { should == config_pf_open_firewall }
      its("pf_trusted_networks")    { should == config_pf_trusted_networks}
      its("port_forwarding_rules")  { should == config_port_forwarding_rules }
      its("firewall_rules")         { should == config_firewall_rules }
      its("security_group_ids")     { should == config_security_group_ids }
      its("display_name")           { should == config_display_name }
      its("group")                  { should == config_group }
      its("security_group_names")   { should == config_security_group_names }
      its("security_groups")        { should == config_security_groups }
      its("ssh_key")                { should == config_ssh_key }
      its("ssh_user")               { should == config_ssh_user }
      its("vm_user")                { should == config_vm_user }
      its("vm_password")            { should == config_vm_password }
      its("private_ip_address")     { should == config_private_ip_address }
      its("expunge_on_destroy")     { should == config_expunge_on_destroy }
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
