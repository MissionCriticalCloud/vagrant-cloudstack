describe 'Basic Network' do
  it 'starts Linux VM with security groups' do
    expect(`vagrant up`).to include(
      'Security Group Awesome_security_group1 created with ID',
      'Security Group Awesome_security_group2 created with ID',
      'Security Group: Awesome_security_group1 (',
      'Security Group: Awesome_security_group2 (',
      'Network name or id will be ignored',
      'Machine is booted and ready for use!'
    )
    expect($?.exitstatus).to eq(0)
  end
  it 'destroys Linux with security groups' do
    expect(`vagrant destroy --force`).to include(
      'Terminating the instance...',
      'Deleted ingress rules',
      'Deleted egress rules'
    )
    expect($?.exitstatus).to eq(0)
  end
end
