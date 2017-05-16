def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each { |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    }
  end
  return nil
end
insert_tee_log = '  2>&1 | tee -a vagrant.log ' if which('tee')

describe 'VM Life Cycle' do
  it 'starts Linux and Windows VM' do
    expect(`vagrant up  #{insert_tee_log}`).to include(
      'linux-box: Machine is booted and ready for use!',
      'windows-box: Machine is booted and ready for use!'
    )
    expect($?.exitstatus).to eq(0)
  end
  it 'destroys Linux and Windows VM' do
    expect(`vagrant destroy --force  #{insert_tee_log}`).to include('Done removing resources')
    expect($?.exitstatus).to eq(0)
  end
end
