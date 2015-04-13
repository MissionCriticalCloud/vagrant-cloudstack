# WARNING: Klarna does not actively use Vagrant to manage any Cloudstack instances anymore, therefore we are not maintaining this repository.

# Vagrant Cloudstack Provider

[![Build Status](https://travis-ci.org/klarna/vagrant-cloudstack.png?branch=master)](https://travis-ci.org/klarna/vagrant-cloudstack)
[![Gem Version](https://badge.fury.io/rb/vagrant-cloudstack.png)](http://badge.fury.io/rb/vagrant-cloudstack)
[![Dependency Status](https://gemnasium.com/klarna/vagrant-cloudstack.png)](https://gemnasium.com/klarna/vagrant-cloudstack)
[![Code climate](https://codeclimate.com/github/klarna/vagrant-cloudstack.png)](https://codeclimate.com/github/klarna/vagrant-cloudstack)
[![Coverage Status](https://coveralls.io/repos/klarna/vagrant-cloudstack/badge.png)](https://coveralls.io/r/klarna/vagrant-cloudstack)

This is a fork of [mitchellh AWS Provider](https://github.com/mitchellh/vagrant-aws/).

This is a [Vagrant](http://www.vagrantup.com) 1.5+ plugin that adds a [Cloudstack](http://cloudstack.apache.org)
provider to Vagrant.

## Features

* SSH into the instances.
* Provision the instances with any built-in Vagrant provisioner.
* Minimal synced folder support via `rsync`.

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
started is to actually use a dummy Cloudstack box and specify all the details
manually within a `config.vm.provider` block. So first, add the dummy
box using any name you want:

```
$ vagrant box add dummy https://github.com/klarna/vagrant-cloudstack/raw/master/dummy.box
...
```

And then make a Vagrantfile that looks like the following, filling in
your information where necessary.

```
Vagrant.configure("2") do |config|
  config.vm.box = "dummy"

  config.vm.provider :cloudstack do |cloudstack, override|
    cloudstack.host = "cloudstack.local"
    cloudstack.path = "/client/api"
    cloudstack.port = "8080"
    cloudstack.scheme = "http"
    cloudstack.api_key = "AAAAAAAAAAAAAAAAAAA"
    cloudstack.secret_key = "AAAAAAAAAAAAAAAAAAA"

    cloudstack.template_id = "AAAAAAAAAAAAAAAAAAA"
    cloudstack.service_offering_id = "AAAAAAAAAAAAAAAAAAA"
    cloudstack.network_id = "AAAAAAAAAAAAAAAAAAA"
    cloudstack.zone_id = "AAAAAAAAAAAAAAAAAAA"
    cloudstack.project_id = "AAAAAAAAAAAAAAAAAAA"
    cloudstack.network_type = "Advanced" # or "Basic"
  end
end
```

Or with names instead of ids:

```
Vagrant.configure("2") do |config|
  config.vm.box = "dummy"

  config.vm.provider :cloudstack do |cloudstack, override|
    cloudstack.host = "cloudstack.local"
    cloudstack.path = "/client/api"
    cloudstack.port = "8080"
    cloudstack.scheme = "http"
    cloudstack.api_key = "AAAAAAAAAAAAAAAAAAA"
    cloudstack.secret_key = "AAAAAAAAAAAAAAAAAAA"

    cloudstack.template_name = "GENERIC-Awesome-Linux"
    cloudstack.service_offering_name = "THE-BESTEST"
    cloudstack.network_name = "WOW-SUCH-FAST-OFFERING"
    cloudstack.zone_name = "District-9"
    cloudstack.name = "doge-is-a-hostname-now"
    # Sadly there is currently no support for the project api in fog.
    cloudstack.project_id = "AAAAAAAAAAAAAAAAAAA"
    cloudstack.network_type = "Advanced" # or "Basic"
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
the [example_box/ directory](https://github.com/klarna/vagrant-cloudstack/tree/master/example_box).
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
* `network_id` - Network uuid that the instance should use
* `network_name` - Network name that the instance should use
* `network_type` - CloudStack Network Type(default: Advanced)
* `project_id` - Project uuid that the instance should belong to 
* `service_offering_id`- Service offering uuid to use for the instance
* `service_offering_name`- Service offering name to use for the instance
* `template_id` - Template uuid to use for the instance
* `template_name` - Template name to use for the instance
* `zone_id` - Zone uuid to launch the instance into
* `zone_name` - Zone uuid to launch the instance into
* `keypair` - SSH keypair name
* `pf_ip_address_id` - IP address ID for port forwarding rule
* `pf_public_port` - Public port for port forwarding rule
* `pf_private_port` - Private port for port forwarding rule
* `display_name` - Display name for the instance
* `group` - Group for the instance
* `ssh_key` - Path to a private key to be used with ssh
* `ssh_user` - User name to be used with ssh

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

### Basic Networking

If you set the `network_type` to `basic`, you can use Security 
Groups and associate rules in your Vagrantfile.

If you already have Security Groups, you can associate them to your
instance, with their IDs:

```ruby
Vagrant.configure("2") do |config|
  # ... other stuff

  config.vm.provider :cloudstack do |cloudstack|
    cloudstack.api_key = "foo"
    cloudstack.secret_key = "bar"
    cloudstack.network_type = "basic"
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
    cloudstack.network_type = "basic"
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
    cloudstack.network_type = "basic"
    cloudstack.security_groups = [
      { 
        :name         => "Awesome_security_group",
        :description  => "Created from the Vagrantfile",
    		:rules 				=> [
				  {:type => "ingress", :protocol => "TCP", :startport => 22, :endport => 22, :cidrlist => "0.0.0.0/0"},
				  {:type => "ingress", :protocol => "TCP", :startport => 80, :endport => 80, :cidrlist => "0.0.0.0/0"},
          {:type => "egress",  :protocol => "TCP", :startport => 81, :endport => 82, :cidrlist => "1.2.3.4/24"},
			  ]
      }
    ]
  end
end
```


## Synced Folders

There is minimal support for synced folders. Upon `vagrant up`,
`vagrant reload`, and `vagrant provision`, the Cloudstack provider will use
`rsync` (if available) to uni-directionally sync the folder to
the remote machine over SSH.

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
