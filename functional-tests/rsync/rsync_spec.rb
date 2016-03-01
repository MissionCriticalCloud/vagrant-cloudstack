describe 'VM RSync' do
  it 'does rsync to the VM' do
    expect(`vagrant up`).to include('Machine is booted and ready for use!')
    expect($?.exitstatus).to eq(0)
    expect(`vagrant ssh -c "ls /etc; echo;"`).to include('Vagrantfile.advanced_networking')
    expect(`vagrant destroy --force`).to include('Terminating the instance...')
    expect($?.exitstatus).to eq(0)
  end
end
