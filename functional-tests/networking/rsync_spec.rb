describe 'Networking features' do
  it 'creates firewall and portwarding rules' do
    expect(`vagrant up`).to include('Machine is booted and ready for use!')
    expect($?.exitstatus).to eq(0)

    expect(`vagrant destroy --force`).to include('Terminating the instance...')
    expect($?.exitstatus).to eq(0)
  end
end
