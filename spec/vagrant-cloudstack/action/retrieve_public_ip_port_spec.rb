require 'spec_helper'
require 'vagrant-cloudstack/action/read_ssh_info'
require 'vagrant-cloudstack/config'

describe VagrantPlugins::Cloudstack::Action::ReadSSHInfo do
  let(:action) {VagrantPlugins::Cloudstack::Action::ReadSSHInfo.new(nil, nil)}

  describe '#fetch_nic_ip_address' do
    subject {action.fetch_nic_ip_address(nics, domain_config)}

    let(:nics) do
      [
          {'networkid' => 'networkid1', 'networkname' => 'networkname1', 'ipaddress' => '127.0.0.1'},
          {'networkid' => 'networkid2', 'networkname' => 'networkname2', 'ipaddress' => '127.0.0.2'},
          {'networkid' => 'networkid3', 'networkname' => 'networkname3', 'ipaddress' => '127.0.0.3'},
      ]
    end

    let(:ssh_network_id) {Vagrant::Plugin::V2::Config::UNSET_VALUE}
    let(:ssh_network_name) {Vagrant::Plugin::V2::Config::UNSET_VALUE}

    let(:domain_config) do
      config = VagrantPlugins::Cloudstack::Config.new
      config.domain_config :cloudstack do |cloudstack|
        cloudstack.ssh_network_id = ssh_network_id
        cloudstack.ssh_network_name = ssh_network_name
      end
      config.finalize!
      config.get_domain_config(:cloudstack)
    end

    context 'without neither ssh_network_id and ssh_network_name' do
      it {should eq '127.0.0.1'
      }
    end

    context 'with ssh_network_id' do
      context 'when exists in nics' do
        let(:ssh_network_id) {'networkid2'
        }

        it {should eq '127.0.0.2'
        }
      end

      context 'when not exists in nics' do
        let(:ssh_network_id) {'unknown'
        }

        it {should eq '127.0.0.1'
        }
      end
    end

    context 'with ssh_network_id' do
      context 'when exists in nics' do
        let(:ssh_network_name) {'networkname3'
        }

        it {should eq '127.0.0.3'
        }
      end

      context 'when not exists in nics' do
        let(:ssh_network_name) {'unknown'
        }

        it {should eq '127.0.0.1'
        }
      end
    end

    context 'with both ssh_network_id and ssh_network_name' do
      context 'when exists in nics' do
        let(:ssh_network_id) {'networkid2'
        }
        let(:ssh_network_name) {'networkname3'
        }

        it {should eq '127.0.0.2'
        }
      end

      context 'when not exists in nics' do
        let(:ssh_network_id) {'unknown'
        }
        let(:ssh_network_name) {'unknown'
        }

        it {should eq '127.0.0.1'
        }
      end
    end
  end
end
