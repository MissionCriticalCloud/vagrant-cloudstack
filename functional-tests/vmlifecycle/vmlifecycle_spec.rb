describe 'VM Life Cycle' do
  it 'starts Linux and Windows VM' do
    expect(`vagrant up`).to include(
      'linux-box: Machine is booted and ready for use!',
      'windows-box: Machine is booted and ready for use!'
    )
    expect($?.exitstatus).to eq(0)
  end
  it 'destroys Linux and Windows VM' do
    expect(`vagrant destroy --force`).to include('Done removing resources')
    expect($?.exitstatus).to eq(0)
  end
end
