FROM debian:8

MAINTAINER Bob van den Heuvel <bvandenheuvel@schubergphilis.com>

# Specify the ChefDK version and channel
ENV CHEFDK_VERSION 0.19
ENV CHEFDK_CHANNEL stable

# Currently the latest version of the plugin has been tested with Vagrant 1.8.1
ENV	VAGRANT_VERSION 1.8.1

# The plugin currently depends on existence of the USER variable...
ENV USER VAC

# Update before all package installations
RUN apt-get update -y && \
   apt-get install -y build-essential liblzma-dev zlib1g-dev git openssh-client curl && \
   ln -sf bash /bin/sh

# Set the locale, seems to be required for all things gem
RUN     apt-get install -y locales  && \
        dpkg-reconfigure -f noninteractive tzdata && \
        sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
        echo 'LANG="en_US.UTF-8"'>/etc/default/locale && \
        dpkg-reconfigure --frontend=noninteractive locales && \
        update-locale LANG=en_US.UTF-8
# Set environment variables AFTER configuration, else breaks
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
#

# Install vagrant and the vagrant-cloudstack plugin
RUN curl -L https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_x86_64.deb > /tmp/vagrant_x86_64.deb && \
    dpkg -i /tmp/vagrant_x86_64.deb && \
    rm -f /tmp/vagrant_x86_64.deb && \
    vagrant plugin install vagrant-cloudstack && \
    vagrant plugin install vagrant-winrm --plugin-version 0.7.0

# Install ChefDK
RUN curl https://omnitruck.chef.io/install.sh | bash -s -- -c ${CHEFDK_CHANNEL} -P chefdk -v ${CHEFDK_VERSION} && \
    echo 'eval "$(chef shell-init bash)"' >> ~/.bashrc && \
    /opt/chefdk/embedded/bin/bundler config --global path vendor/bundle && \
    /opt/chefdk/embedded/bin/bundler config --global bin vendor/bin && \
    /opt/chefdk/embedded/bin/gem install kitchen-vagrant -v 0.20.0

WORKDIR "/work"

VOLUME ["/work"]
