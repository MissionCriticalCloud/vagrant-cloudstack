# Vagrant Cloudstack Provider

[![Build Status](https://travis-ci.org/missioncriticalcloud/vagrant-cloudstack.png?branch=master)](https://travis-ci.org/missioncriticalcloud/vagrant-cloudstack)
[![Gem Version](https://badge.fury.io/rb/vagrant-cloudstack.png)](http://badge.fury.io/rb/vagrant-cloudstack)
[![Code climate](https://codeclimate.com/github/missioncriticalcloud/vagrant-cloudstack.png)](https://codeclimate.com/github/missioncriticalcloud/vagrant-cloudstack)
[![Coverage Status](https://coveralls.io/repos/missioncriticalcloud/vagrant-cloudstack/badge.svg?branch=master)](https://coveralls.io/r/missioncriticalcloud/vagrant-cloudstack?branch=master)
[![Gem Version](https://badge.fury.io/rb/vagrant-cloudstack.svg)](http://badge.fury.io/rb/vagrant-cloudstack)

This is a fork of [mitchellh AWS Provider](https://github.com/mitchellh/vagrant-aws/).

This is a [Vagrant](http://www.vagrantup.com) 1.5+ plugin that adds a [Cloudstack](http://cloudstack.apache.org)
provider to Vagrant for use with either [Cosmic](https://github.com/MissionCriticalCloud/cosmic) or [Cloudstack](http://cloudstack.apache.org).

## Features

* SSH into the instances.
* Provision the instances with any built-in Vagrant provisioner.
* Minimal synced folder support via `rsync`/`winrm`.

## Usage

Install using standard Vagrant 1.1+ plugin installation methods. After
installing, `vagrant up` and specify the `cloudstack` provider. An example is
shown below.

```
$ vagrant plugin install vagrant-cloudstack
...
$ vagrant up --provider=cloudstack
...
```

Of course prior to doing this, you'll need to obtain an Cloudstack-compatible
box file for Vagrant.

## Quick Start

After installing the plugin (instructions above), the quickest way to get
started is to actually make a Vagrantfile that looks like the following, filling in
your information where necessary.

```
Vagrant.configure("2") do |config|
  config.vm.box = "${cloudstack.template_name}"

  config.vm.provider :cloudstack do |cloudstack, override|
    cloudstack.host = "cloudstack.local"
    cloudstack.path = "/client/api"
    cloudstack.port = "8080"
    cloudstack.scheme = "http"
    cloudstack.api_key = "AAAAAAAAAAAAAAAAAAA"
    cloudstack.secret_key = "AAAAAAAAAAAAAAAAAAA"

    cloudstack.service_offering_id = "AAAAAAAAAAAAAAAAAAA"
    cloudstack.disk_offering_id = "AAAAAAAAAAAAAAAAAAA"
    cloudstack.network_id = "AAAAAAAAAAAAAAAAAAA"
    cloudstack.zone_id = "AAAAAAAAAAAAAAAAAAA"
    cloudstack.project_id = "AAAAAAAAAAAAAAAAAAA"
  end
end
```

Or with names instead of ids:

```
Vagrant.configure("2") do |config|
  config.vm.box = "${cloudstack.template_name}"

  config.vm.provider :cloudstack do |cloudstack, override|
    cloudstack.host = "cloudstack.local"
    cloudstack.path = "/client/api"
    cloudstack.port = "8080"
    cloudstack.scheme = "http"
    cloudstack.api_key = "AAAAAAAAAAAAAAAAAAA"
    cloudstack.secret_key = "AAAAAAAAAAAAAAAAAAA"

    cloudstack.service_offering_name = "THE-BESTEST"
    cloudstack.disk_offering_name = "THE-LARGEST-OFFER-AVAILABLE"
    cloudstack.network_name = "WOW-SUCH-FAST-OFFERING"
    cloudstack.zone_name = "District-9"
    cloudstack.name = "doge-is-a-hostname-now"
    # Sadly there is currently no support for the project api in fog.
    cloudstack.project_id = "AAAAAAAAAAAAAAAAAAA"
  end
end
```


Note that normally a lot of this boilerplate is encoded within the box
file, but the box file used for the quick start, the "dummy" box, has
no preconfigured defaults.

And then run `vagrant up --provider=cloudstack`.

This will start an instance in Cloudstack. And assuming your template
on Cloudstack is Vagrant compatible _(vagrant user with official
vagrant pub key in authorized_keys)_ SSH and provisioning will work as
well.

## Box Format

Every provider in Vagrant must introduce a custom box format. This
provider introduces `cloudstack` boxes. You can view an example box in
the [example_box/ directory](https://github.com/missioncriticalcloud/vagrant-cloudstack/tree/master/example_box).
That directory also contains instructions on how to build a box.

The box format is basically just the required `metadata.json` file
along with a `Vagrantfile` that does default settings for the
provider-specific configuration for this provider.

## Configuration

This provider exposes quite a few provider-specific configuration options. Most of the settings
have both an id and a name setting and you can chose to use either (i.e network_id or network_name).
This gives the possibility to use the easier to remember name instead of the UUID,
this will also enable you to upgrade the different settings in your cloud without having
to update UUIDs in your Vagrantfile. If both are specified, the id parameter takes precedence.

* `name` - Hostname of the created machine
* `host` - Cloudstack api host
* `path` - Cloudstack api path
* `port` - Cloudstack api port
* `scheme` - Cloudstack api scheme _(defaults: https (thanks to the resolution order in fog))_
* `api_key` - The api key for accessing Cloudstack
* `secret_key` - The secret key for accessing Cloudstack
* `instance_ready_timeout` - The number of seconds to wait for the instance
  to become "ready" in Cloudstack. Defaults to 120 seconds.
* `domain_id` - Domain id to launch the instance into
* `network_id` - Network uuid(s) that the instance should use
  - `network_id` is single value (e.g. `"AAAA"`) or multiple values (e.g. `["AAAA", "BBBB"]`)
* `network_name` - Network name(s) that the instance should use
  - `network_name` is single value (e.g. `"AAAA"`) or multiple values (e.g. `["AAAA", "BBBB"]`)
* `project_id` - Project uuid that the instance should belong to
* `service_offering_id`- Service offering uuid to use for the instance
* `service_offering_name`- Service offering name to use for the instance
* `template_id` - Template uuid to use for the instance
* `template_name` - Template name to use for the instance, defaults to Vagrants config.vm.box
* `zone_id` - Zone uuid to launch the instance into
* `zone_name` - Zone uuid to launch the instance into
* `keypair` - SSH keypair name, if neither'keypair' nor 'ssh_key' have been specified, a temporary keypair will be created
* `static_nat` - static nat for the virtual machine
* `pf_ip_address_id` - IP address ID for port forwarding rule
* `pf_ip_address` - IP address for port forwarding rule
* `pf_public_port` - Public Communicator port for port forwarding rule
* `pf_public_rdp_port` - Public RDP port for port forwarding rule
* `pf_public_port_randomrange` - If public port is omited, a port from this range wll be used (default `{:start=>49152, :end=>65535}`)
* `pf_private_port` - Private port for port forwarding rule (defaults to respective Communicator protocol)
* `pf_open_firewall` - Flag to enable/disable automatic open firewall rule (by CloudStack)
* `pf_trusted_networks` - Array of CIDRs or (array of) comma-separated string of CIDRs to network(s) to 
  - automatically (by plugin) generate firewall rules for, ignored if `pf_open_firewall` set `true`
  - use as default for firewall rules where source CIDR is missing
* `port_forwarding_rules` - Port forwarding rules for the virtual machine
* `firewall_rules` - Firewall rules
* `display_name` - Display name for the instance
* `group` - Group for the instance
* `ssh_key` - Path to a private key to be used with ssh _(defaults to Vagrant's `config.ssh.private_key_path`)_
* `ssh_user` - User name to be used with ssh _(defaults to Vagrant's `config.ssh.username`)_
* `ssh_network_id` - The network_id to be used when loging in to the vm via ssh _(defaults to first nic)_
* `ssh_network_name` - The network_name to be used when loging in to the vm via ssh _(defaults to first nic)_
  - Use either `ssh_network_id` or `ssh_network_name`. If specified both , use `ssh_network_id`
* `vm_user` - User name to be used with winrm _(defaults to Vagrant's `config.winrm.username`)_
* `vm_password` - Password to be used with winrm. _(If the CloudStack template is "Password Enabled", leaving this unset will trigger the plugin to retrieve and use it.)_
* `private_ip_address` - private (static)ip address to be used by the virtual machine
* `expunge_on_destroy` - Flag to enable/disable expunge vm on destroy

These can be set like typical provider-specific configuration:

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :cloudstack do |cloudstack|
    cloudstack.api_key = "foo"
    cloudstack.secret_key = "bar"
  end
end
```

In addition to the above top-level configs, you can use the `region_config`
method to specify region-specific overrides within your Vagrantfile. Note
that the top-level `region` config must always be specified to choose which
region you want to actually use, however. This looks like this:

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :cloudstack do |cloudstack|
    cloudstack.api_key = "foo"
    cloudstack.secret_key = "bar"
    cloudstack.domain = "internal"

    # Simple domain config
    cloudstack.domain_config "internal", :network_id => "AAAAAAAAAAAAAAAAAAA"

    # More comprehensive region config
    cloudstack.domain_config "internal" do |domain|
      domain.network_id = "AAAAAAAAAAAAAAAAAAA"
      domain.service_offering_id = "AAAAAAAAAAAAAAAAAAA"
    end
  end
end
```

The domain-specific configurations will override the top-level
configurations when that domain is used. They otherwise inherit
the top-level configurations, as you would probably expect.

## Networks

Networking features in the form of `config.vm.network` are not
supported with `vagrant-cloudstack`, currently. If any of these are
specified, Vagrant will emit a warning, but will otherwise boot
the Cloudstack machine.

### Basic networking versus Advanced networking

The plugin will determine this network type dynamically from the zone.
The setting `network_type` in the Vagrant file has been deprecated,
and is silently ignored.

### Basic Networking

If the network type of your zone is `basic`, you can use Security
Groups and associate rules in your Vagrantfile.

If you already have Security Groups, you can associate them to your
instance, with their IDs:

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :cloudstack do |cloudstack|
    cloudstack.api_key = "foo"
    cloudstack.secret_key = "bar"
    cloudstack.security_group_ids = ['aaaa-bbbb-cccc-dddd', '1111-2222-3333-4444']
  end
end
```

or their names:

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :cloudstack do |cloudstack|
    cloudstack.api_key = "foo"
    cloudstack.secret_key = "bar"
    cloudstack.security_group_names = ['
min_fantastiska_security_group', 'another_security_grupp']
  end
end
```

But you can also create your Security Groups in the Vagrantfile:

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :cloudstack do |cloudstack|
    cloudstack.api_key = "foo"
    cloudstack.secret_key = "bar"
    cloudstack.security_groups = [
      {
        :name         => "Awesome_security_group",
        :description  => "Created from the Vagrantfile",
          :rules => [
        {:type => "ingress", :protocol => "TCP", :startport => 22, :endport => 22, :cidrlist => "0.0.0.0/0"},
        {:type => "ingress", :protocol => "TCP", :startport => 80, :endport => 80, :cidrlist => "0.0.0.0/0"},
        {:type => "egress",  :protocol => "TCP", :startport => 81, :endport => 82, :cidrlist => "1.2.3.4/24"},
    ]
      }
    ]
  end
end
```

### Static NAT, Firewall, Port forwarding

You can create your static nat, firewall and port forwarding rules in the Vagrantfile.
You can use this rule to access virtual machine from an external machine.

The rules created in Vagrantfile are removed when the virtual machine is destroyed.

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :cloudstack do |cloudstack|

    override.ssh.host = "X.X.X.X"

    cloudstack.static_nat = [
      { :ipaddress => "A.A.A.A"}
    ]

    cloudstack.port_forwarding_rules = [
      { :ipaddress => "X.X.X.X", :protocol => "tcp", :publicport => 22, :privateport  => 22, :openfirewall => false },
      { :ipaddress => "X.X.X.X", :protocol => "tcp", :publicport => 80, :privateport  => 80, :openfirewall => false }
    ]

    cloudstack.firewall_rules = [
      { :ipaddress => "A.A.A.A", :cidrlist  => "1.2.3.4/24", :protocol => "icmp", :icmptype => 8, :icmpcode => 0 },
      { :ipaddress => "X.X.X.X", :cidrlist  => "1.2.3.4/24", :protocol => "tcp", :startport => 22, :endport => 22 },
      { :ipaddress => "X.X.X.X", :cidrlist  => "1.2.3.4/24", :protocol => "tcp", :startport => 80, :endport => 80 }
    ]

  end
end
```
Most values in the firewall and portforwarding rules are not mandatory, except either startport/endport or privateport/publicport
* `:ipaddress` - defaults to `pf_ip_address`
* `:protocol` - defaults to `'tcp'`
* `:publicport` - defaults to `:privateport`
* `:privateport` - defaults to `:publicport`
* `:openfirewall` - defaults to `pf_open_firewall`
* `:cidrlist` - defaults to `pf_trusted_networks`
* `:startport` - defaults to `:endport`
* `:endport` - not required by CloudStack


For only allowing Vagrant to access the box for further provisioning (SSH/WinRM), and opening the Firewall for some subnets, the following config is sufficient:
```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :cloudstack do |cloudstack|
    cloudstack.pf_open_firewall      = "false"
    cloudstack.pf_ip_address         = X.X.X.X
    cloudstack.pf_trusted_networks   = [ "1.2.3.4/24" , "11.22.33.44/32" ]
  end
end
```
Where X.X.X.X is the ip of the respective CloudStack network, this will automatically map the port of the used Communicator (SSH/Winrm) via a random public port, open the Firewall and set Vagrant to use it.

The plugin can also automatically generate firewall rules off of the portforwarding rules:
```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :cloudstack do |cloudstack|

    cloudstack.pf_trusted_networks   = "1.2.3.4/24,11.22.33.44/32"
    cloudstack.port_forwarding_rules = [
      { :privateport  => 22, :generate_firewall => true },
      { :privateport  => 80, :generate_firewall => true }
    ]

  end
end
```

### Virtual Router versus VPC
Both Virtual Routers and VPCs are supported when using port-forwarding and firewall. This is automatically determined by the specific `pf_ip_address`.

Note that there are architectural differences in CloudStack which the configuration must adhere to.

For VPC:
* `pf_open_firewall` will be ignored as global setting and (specifically) in `port_forwarding_rules`
* for `firewall_rules` to open access for `port_forwarding_rules`, the firewall rule should allow traffic for the `:privateport` port.

For Virtual Router:
* for `firewall_rules` to open access for `port_forwarding_rules`, the firewall rule should allow traffic for the `:publicport` port.

Usage of other attributes and features work with both network types. Such as `:generate_firewall` for portforwarding rules, or `pf_trusted_networks` to automatically generate rules for the Communicator.

## Synced Folders

There is minimal support for synced folders. Upon `vagrant up`, `vagrant reload`, and `vagrant provision`, the Cloudstack provider will use `rsync` (if available) to uni-directionally sync the folder to the remote machine over SSH, and use Vagrant plugin `vagrant-winrm-syncedfolders` (if available) to uni-directionally sync the folder to the remote machine over WinRM.

This is good enough for all built-in Vagrant provisioners (shell,
chef, and puppet) to work!

### User data

You can specify user data for the instance being booted.

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :cloudstack do |cloudstack|
    # Option 1: a single string
    cloudstack.user_data = "#!/bin/bash\necho 'got user data' > /tmp/user_data.log\necho"

    # Option 2: use a file
    cloudstack.user_data = File.read("user_data.txt")
  end
end
```

The maximum length of user_data is around 1500 bytes with Cloudstack API < 4.2 ( base64 encoded user_data must be < 2048 bytes)

## Development

To work on the `vagrant-cloudstack` plugin, clone this repository out, and use
[Bundler](http://gembundler.com) to get the dependencies:

```
$ bundle
```

Once you have the dependencies, verify the unit tests pass with `rake`:

```
$ bundle exec rake
```

If the unit-tests pass, verify the plugin is functionaly good by running the functional tests with bats.
Before running the tests you need to export a set of variables that are used in the tests. Look at the
Rake file for the required variables, or run the following Rake command to check:
```
bundle exec rake functional_tests:check_environment
```

Run all functional tests by executing:
```
bundle exec rake functional_tests:all
```

If those pass, you're ready to start developing the plugin. You can test
the plugin without installing it into your Vagrant environment by just
creating a `Vagrantfile` in the top level of this directory (it is gitignored)
and add the following line to your `Vagrantfile`
```ruby
Vagrant.require_plugin "vagrant-cloudstack"
```
Use bundler to execute Vagrant:

```
$ bundle exec vagrant up --provider=cloudstack
```
