describe 'Networking features' do
  it 'creates firewall and portwarding rules for both Virtual Router and VPC' do
    expect(`vagrant up`).to include(
                                'VRbox1: Machine is booted and ready for use!',
                                'VRbox2: Machine is booted and ready for use!',
                                'VPCbox1: Machine is booted and ready for use!',
                                'VPCbox2: Machine is booted and ready for use!'
    )
    expect($?.exitstatus).to eq(0)

    expect(`vagrant destroy --force`).to include('Terminating the instance...')
    expect($?.exitstatus).to eq(0)
  end
end
