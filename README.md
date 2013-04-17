# Vagrant Cloudstack Provider

This is a fork of [mitchellh AWS Provider](https://github.com/mitchellh/vagrant-aws/).

This is a [Vagrant](http://www.vagrantup.com) 1.2+ plugin that adds an [Cloudstack](http://cloudstack.apache.org)
provider to Vagrant.

**NOTE:** This plugin requires Vagrant 1.2+,

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
    cloudstack.port = "8080"
    cloudstack.scheme = "http"
    cloudstack.api_key = "AAAAAAAAAAAAAAAAAAA"
    cloudstack.secret_key = "AAAAAAAAAAAAAAAAAAA"

    cs.template_id = "AAAAAAAAAAAAAAAAAAA"
    cs.service_offering_id = "AAAAAAAAAAAAAAAAAAA"
    cs.network_id = "AAAAAAAAAAAAAAAAAAA"
    cs.zone_id = "AAAAAAAAAAAAAAAAAAA"
    cs.project_id = "AAAAAAAAAAAAAAAAAAA"
  end
end
```

Note that normally a lot of this boilerplate is encoded within the box
file, but the box file used for the quick start, the "dummy" box, has
no preconfigured defaults.

And then run `vagrant up --provider=cloudstack`.

This will start an instance in Cloudstack. And assuming your template on Cloudstack is Vagrant compatible _(vagrant user with official vagrant pub key in authorized_keys)_ SSH and provisioning will work as well.

## Box Format

Every provider in Vagrant must introduce a custom box format. This
provider introduces `cloudstack` boxes. You can view an example box in
the [example_box/ directory](https://github.com/klarna/vagrant-cloudstack/tree/master/example_box).
That directory also contains instructions on how to build a box.

The box format is basically just the required `metadata.json` file
along with a `Vagrantfile` that does default settings for the
provider-specific configuration for this provider.

## Configuration

This provider exposes quite a few provider-specific configuration options:

* `host` - Cloudstack api host
* `port` - Cloudstack api port
* `scheme` - Cloudstack api scheme _(default: http)_
* `api_key` - The api key for accessing Cloudstack
* `secret_key` - The secret key for accessing Cloudstack
* `instance_ready_timeout` - The number of seconds to wait for the instance
  to become "ready" in Cloudstack. Defaults to 120 seconds.
* `domain_id` - Domain id to launch the instance into
* `network_id` - Network uuid that the instance should use
* `project_id` - Project uuid that the instance should belong to 
* `service_offering_id`- Service offering uuid to use for the instance
* `template_id` - Template uuid to use for the instance
* `zone_id` - Zone uuid to launch the instance into

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

## Synced Folders

There is minimal support for synced folders. Upon `vagrant up`,
`vagrant reload`, and `vagrant provision`, the Cloudstack provider will use
`rsync` (if available) to uni-directionally sync the folder to
the remote machine over SSH.

This is good enough for all built-in Vagrant provisioners (shell,
chef, and puppet) to work!

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
that uses it, and uses bundler to execute Vagrant:

```
$ bundle exec vagrant up --provider=cloudstack
```
