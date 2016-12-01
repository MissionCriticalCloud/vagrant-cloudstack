# Vagrant Cloudstack Container

This container contains some tools commonly used with the vagrant-cloudstack plugin
## dev
The versions have been specifically tuned to provide a working set for development of the plugin. To this end also developer tools (e.g. make, g++) are installed to enable bundler to pull in and compile required gems.
So this one is _required_ for developing and testing the plugin from (latest, master) source.
* [Vagrant](http://www.vagrantup.com) 1.8.1
* [Vagrant-cloudstack](https://github.com/missioncriticalcloud/vagrant-cloudstack) plugin _current_
* [Vagrant-winrm](https://github.com/criteo/vagrant-winrm) 0.7.0 (latest)
* [Chef-DK](https://downloads.chef.io/chef-dk/) 0.10.0
* [Kitchen-Vagrant](https://github.com/test-kitchen/kitchen-vagrant) 0.20.0

As the container is build automatically on triggers, latest versions are latest at time of (re)build_
 

## latest_dependencies
This may not work for everyone as we try to use latest, but also stable combination of versions.
For now building on top of the "dev" container, with Vagrant 1.8.1.
* [Vagrant](http://www.vagrantup.com) 1.8.1
* [Vagrant-cloudstack](https://github.com/missioncriticalcloud/vagrant-cloudstack) plugin _current_
* [Vagrant-winrm](https://github.com/criteo/vagrant-winrm) 0.7.0 (latest)
* [Chef-DK](https://downloads.chef.io/chef-dk/) 0.19
* [Kitchen-Vagrant](https://github.com/test-kitchen/kitchen-vagrant) 0.20.0

_As the container is build automatically on triggers, latest versions are latest at time of (re)build_


## chefdk_0_17
This will install chef-client 12.13.37 which is needed for some compatibilty reasons.
* [Vagrant](http://www.vagrantup.com) 1.8.1
* [Vagrant-cloudstack](https://github.com/missioncriticalcloud/vagrant-cloudstack) plugin _current_
* [Vagrant-winrm](https://github.com/criteo/vagrant-winrm) 0.7.0 (latest)
* [Chef-DK](https://downloads.chef.io/chef-dk/) 0.17
* [Kitchen-Vagrant](https://github.com/test-kitchen/kitchen-vagrant) 0.20.0

_As the container is build automatically on triggers, latest versions are latest at time of (re)build_


Links to the respective Dockerfiles:
* [dev](https://raw.githubusercontent.com/MissionCriticalCloud/vagrant-cloudstack/master/Docker/Dockerfile)
* [latest_dependencies](https://raw.githubusercontent.com/MissionCriticalCloud/vagrant-cloudstack/master/Docker/Dockerfile.latest_dependencies)
* [chefdk_0_17](https://raw.githubusercontent.com/MissionCriticalCloud/vagrant-cloudstack/master/Docker/Dockerfile.chefdk_0_17)

## Features
* Run Vagrant with the plugin
* Run Test-Kitchen with the plugin
* Using Bundler, run Vagrant/Test-Kitchen with vagrant-cloudstack from source

## Usage
Retrieve the docker container:
```
docker pull missioncriticalcloud/vagrant-cloudstack
```
Change into the directory containing your project (Vagrantfile, .kitchen.yml), and execute:
```
docker run -ti --rm  -v $(pwd):/work missioncriticalcloud/vagrant-cloudstack /bin/bash
```
This provides a bash shell (in the container) where you can execute e.g. Vagrant, Test-Kitchen, Bundler.

For use of Vagrantfile or .kitchen.yml files containing environment variables, environment variables need to be specified in the docker run, e.g.:
```
docker run \
-e USER=${USER} \
-e CLOUDSTACK_API_KEY=${CLOUDSTACK_API_KEY} \
-e CLOUDSTACK_SECRET_KEY=${CLOUDSTACK_SECRET_KEY} \
-ti --rm  -v $(pwd):/work missioncriticalcloud/vagrant-cloudstack /bin/bash
```

For actual development of the plugin, a lot more variables are required. To this end you can use the [bash script `vac.sh`](https://raw.githubusercontent.com/MissionCriticalCloud/vagrant-cloudstack/master/Docker/vac.sh) or [PowerShell script `vac.ps1`](https://raw.githubusercontent.com/MissionCriticalCloud/vagrant-cloudstack/master/Docker/vac.ps1) in the git repo.

_Note on usage of SSH keyfile_: As the container is mounted on a specific folder (`$(pwd)`), the keyfile must be specified (by `SSH_KEY`) relative to, __and within__, the specified folder!

## Version notes
### Vagrant
Development of the plugin, means running Vagrant from source, in combination with the specific bundler version (conflict) between ChefDK and Vagrant and ruby version (conflict) between ChefDK and Vagrant, leads to the following version combination:

"dev" container:
* Vagrant 1.8.1
* ChefDK 0.10.0

### ChefDK
Based on (somewhat subjective :) experience, the latest version of ChefDK is mostly compatible, is used as latest version.

"latest_dependensies" container:
* ChefDK 0.19

For convenience of some reported incompatibilities, a separate container is defined:
"chefdk_0_17" container:
* ChefDK 0.17

### Kitchen-Vagrant plugin
Due to new functionality in this plugin (0.21.0), using existing features, the plugin creates a Vagrantfile which has problems executing. This possibly revealed bugs in Vagrant, which might be fixed in newer Vagrant versions.
Untill a new Vagrant is in use, this plugin will be pinned to the latest working combination.

Bugs reported to kitchen-vagrant:
 * [Windows: The shared folder guest path must be absolute: $env:TEMPomnibusche #256](https://github.com/test-kitchen/kitchen-vagrant/issues/256)
 * [Problem with synced_folder (on Kubernetes) v0.20.0->v0.21.0 #257](https://github.com/test-kitchen/kitchen-vagrant/issues/257)


all containers:
* Kitchen-Vagrant 0.20.0

### Vagrant-WinRM
Latest (tested) version at moment of writing is 0.7.0

all containers:
* Kitchen-Vagrant 0.7.0
