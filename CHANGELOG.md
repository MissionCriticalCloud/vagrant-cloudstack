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
