# Vagrant Cloudstack Container

This container contains some tools commonly used with the vagrant-cloudstack plugin
## latest
The versions have been specifically tuned to provide a working set for development of the plugin. To this end also developer tools (e.g. make, g++) are installed to enable bundler to pull in and compile required gems.
So this one is _required_ for developing and testing the plugin from (latest, master) source.
* [Vagrant](http://www.vagrantup.com) 1.8.1
* [Vagrant-cloudstack](https://github.com/missioncriticalcloud/vagrant-cloudstack) plugin latest
* [Vagrant-winrm](https://github.com/criteo/vagrant-winrm) latest
* [Chef-DK](https://downloads.chef.io/chef-dk/) 0.10.0
* [Kitchen-Vagrant](https://github.com/test-kitchen/kitchen-vagrant) latest
_As the container is build automatically on triggers, latest versions are latest at time of (re)build_
 

## latest_dependencies
This may not work for everyone as we try to use latest, but also stable combination of versions.
* [Vagrant](http://www.vagrantup.com) 1.8.1
* [Vagrant-cloudstack](https://github.com/missioncriticalcloud/vagrant-cloudstack) plugin latest
* [Vagrant-winrm](https://github.com/criteo/vagrant-winrm) latest
* [Chef-DK](https://downloads.chef.io/chef-dk/) 0.15.15
* [Kitchen-Vagrant](https://github.com/test-kitchen/kitchen-vagrant) latest
_As the container is build automatically on triggers, latest versions are latest at time of (re)build_

Links to the respective Dockerfiles:
* [latest](https://raw.githubusercontent.com/MissionCriticalCloud/vagrant-cloudstack/master/Docker/Dockerfile)
* [latest_dependencies](https://raw.githubusercontent.com/MissionCriticalCloud/vagrant-cloudstack/master/Docker/Dockerfile.latest_dependencies)

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
