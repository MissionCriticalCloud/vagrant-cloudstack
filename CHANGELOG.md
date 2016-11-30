# 1.4.0 (Nov 30, 2016)
* Support multiple network ids and network names (PR #148)
* Add ssh_network_id and ssh_network_name configuration (PR #149)
* Add (firewall management for) VPC support (PR #151)
* Remove additional data disk on destroy (PR #152)
* Add Docker containers for development and testing (PR #159)
* CloudStack >= 4.6 list all offerings / templates. (PR #161)

# 1.3.0 (Mar 24, 2016)
* Automate port forwarding for RDP for Windows guests (PR #117)
* Specify `trusted_networks` by Array (PR #121)
* Random public port range is specified by hash using `:start` and `:end` (PR #122)
* Generate firewall rule from port forward rules automatically (PR #123)
* Let firewall rule elements (`ipaddress`,`protocol`,`startport`) use defaults (PR #123)
* Generate SSH keypair for lifetime of VM (PR #125)
* Deprecate usage in Vagrantfile of `cloudstack.network_type` (PR #134)
* Determine dynamically from ZONE if 'Basic' or 'Advanced' networking  (PR #134)
* Allow trusted_networks as both string or array (PR #146)

# 1.2.0 (Sep 4, 2015)
* Add support for disk offering (PR#89)
* Fix bug open file handles on Windows (PR#98)
* Add support for Windows guests (PR#96)
* Automate port forwarding for the Communicator (PR#104)
* Allow setting to open Firewall to specific network (PR#99)
* Make config.vm.box an optional setting in Vagrantfile (PR#105)

# 1.1.0 (May 26, 2015)
* Allow setting VM private IP in config (PR #73)
* Fix several coding style issues (PR #76, #77, #78)
* Fix bug when destroying VM created with Static NAT and firewall rules (PR #81)
* Allow expunging VM on destroy (PR #75)
* Make `network_type` optional, and defaulting to "Basic" (PR #82)

# 1.0.0 (May 5, 2015)
* Use vagrant's built-in rsync synced folder (PR #57)
* Enable creating custom static NAT, port forwarding, firewall rules (PR #59)
* Fixed bug when `network_id` and `network_name` are not specified in Vagrantfile (PR #59)
* Enable setting SSH user name and private key to access VM (PR #64)
* Fixed bug when `vagrant destroy` destroys other VMs (PR #66)
* Enable toggling port forwarding automatically adding an open firewall rule (PR #70)

# 0.10.0 (Sep 11, 2014)
* Clean up code base DRY
* Improve documentation
* Use URL safe base 64 encoding

# 0.9.1 (Jun 29, 2014)
* Fixed a bug intrcduced in 0.9.0, where we failed to fetch correct
  name because we didn't pass the correct parameters.

# 0.9.0 (Jun 25, 2014)
* Clean up of dead code and comments.
* Re-organize imports and code.
* Corrects the dependency on Vagrant 1.5+
* Updates documentation to refelect the above.
* Now supports setting the machine hostname in Vagrantfile

# 0.8.0 (Jun 24, 2014)
* Remove unused code.
* Add support for specifying most resources by name. Where applicable there is
  a matching _name config for the _id configs.
  Note: in this release there were no support for the project apis in fog,
  therefore there is no project_name config.

# 0.7.0 (Jun 17, 2014)
* Change the resolution order of how we discover the scheme to talk to the cloud.
  This is a possibly breaking change.

# 0.6.0 (May 13, 2014)

* Bump the Ruby version to 2.0.0-p481
* The API and secret keys can now be passed through environment
  variables CLOUDSTACK_API_KEY and CLOUDSTACK_SECRET_KEY.

# 0.5.0 (Apr 29, 2014)

* Use latest version of upstream fog which contains some much needed
  improvements to the Cloudstack support. Closes #10 for example.

# 0.4.3 (Apr 15, 2014)

* Update README to reflect Vagrant version needed

# 0.4.2 (Apr 15, 2014)

* Add support for userdata

# 0.4.1 (Apr 14, 2014)

* Add support for cygwin paths

# 0.4.0 (Mar 30, 2014)

* Fix for Vagrant > =1.5 [GH-29]

# 0.3.0 (Mar 3, 2014)

* Update fog to latest version (1.20.0)
* Update ruby version to 2.0.0-p451
* Add Gitter.im notification

# 0.2.1 (Jan 12, 2014)

* Remove extranous printout

# 0.2.0 (Jan 8, 2014)

* Add display name and group support
* Add support for security groups
* Bump versions of dependencies

# 0.1.2 (Dec 12, 2013)
* Version bump to gemspec configucation to use shared email

# 0.1.1 (Dec 11, 2013)

* Enable Vagrant 1.4 compability
* Add support for security groups
* Add helper script to build a RPM for easier deployment

# 0.1.0 (Dec 3, 2013)
* Plugin now enables parallelization by default.
  * This behaviour can be turned off by invoking vagrant with
    --no-parallel (this flag requires vagrant 1.2.1)
* Added support for starting, stoping and reloading machines.
* Added support for portforwarding and adding ssh keys.
* Added support for basic network type.
  * Basic means that there is no need to specify a network_id
    to connecto to.
  * Default network type is advanced.

# 0.0.2 (May 3, 2013)

* Renamed module from CloudStack to Cloudstack
* Renamed configurations to match Cloudstack
  * domain -> domain_id
  * offering_id -> service_offering_id
* Added specc test for all provider specific configurations

# 0.0.1 (April 17, 2013)

* Forked into a Cloudstack plugin

# 0.2.1 (April 16, 2013)

* Got rid of extranneous references to old SSH settings.

# 0.2.0 (April 16, 2013)

* Add support for `vagrant ssh -c` [GH-42]
* Ability to specify a timeout for waiting for instances to become ready. [GH-44]
* Better error message if instance didn't become ready in time.
* Connection can now be done using IAM profiles. [GH-41]

# 0.1.3 (April 9, 2013)

* The `AWS_ACCESS_KEY` and `AWS_SECRET_KEY` will be used if available
  and no specific keys are set in the Vagrantfile. [GH-33]
* Fix issues with SSH on VPCs, the correct IP is used. [GH-30]
* Exclude the ".vagrant" directory from rsync.
* Implement `:disabled` flag support for shared folders. [GH-29]
* `aws.user_data` to specify user data on the instance. [GH-26]

# 0.1.2 (March 22, 2013)

* Choose the proper region when connecting to AWS. [GH-9]
* Configurable SSH port. [GH-13]
* Support other AWS-compatible API endpoints with `config.endpoint`
  and `config.version`. [GH-6]
* Disable strict host key checking on rsync so known hosts aren't an issue. [GH-7]

# 0.1.1 (March 18, 2013)

* Up fog dependency for Vagrant 1.1.1

# 0.1.0 (March 14, 2013)

* Initial release.
