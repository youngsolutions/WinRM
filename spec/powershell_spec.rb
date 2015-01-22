# encoding: UTF-8
describe 'winrm client powershell', integration: true do
  before(:all) do
    @winrm = winrm_connection
  end

  describe 'empty string' do
    subject(:output) { @winrm.powershell('') }
    it { should have_exit_code 4_294_770_688 }
    it { should have_stderr_match(/Cannot process the command because of a missing parameter/) }
  end

  describe 'ipconfig' do
    subject(:output) { @winrm.powershell('ipconfig') }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/Windows IP Configuration/) }
    it { should have_no_stderr }
  end

  describe 'echo \'hello world\' using apostrophes' do
    subject(:output) { @winrm.powershell("echo 'hello world'") }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/hello world/) }
    it { should have_no_stderr }
  end

  describe 'dir with incorrect argument /z' do
    subject(:output) { @winrm.powershell('dir /z') }
    it { should have_exit_code 1 }
    it { should have_no_stdout }
  end

  describe 'Math area calculation' do
    subject(:output) do
      @winrm.powershell(<<-EOH
        $diameter = 4.5
        $area = [Math]::pow([Math]::PI * ($diameter/2), 2)
        Write-Host $area
      EOH
      )
    end
    it { should have_exit_code 0 }
    it { should have_stdout_match(/49.9648722805149/) }
    it { should have_no_stderr }
  end

  describe 'ipconfig with a block' do
    subject(:stdout) do
      outvar = ''
      @winrm.powershell('ipconfig') do |stdout, _stderr|
        outvar << stdout
      end
      outvar
    end
    it { should match(/Windows IP Configuration/) }
  end

  describe 'capturing output from Write-Host and Write-Error' do
    subject(:output) do
      script = <<-eos
      Write-Host 'Hello'
      $host.ui.WriteErrorLine(', world!')
      eos

      @captured_stdout, @captured_stderr = '', ''
      @winrm.powershell(script) do |stdout, stderr|
        @captured_stdout << stdout if stdout
        @captured_stderr << stderr if stderr
      end
    end

    it 'should have stdout' do
      expect(output.stdout).to eq("Hello\n")
      expect(output.stdout).to eq(@captured_stdout)
    end

    it 'should have stderr' do
      # TODO: Option to parse CLIXML
      # expect(output.output).to eq("Hello\n, world!")
      # expect(output.stderr).to eq(", world!")
      expect(output.stderr).to eq(
        "#< CLIXML\r\n<Objs Version=\"1.1.0.1\" " \
        "xmlns=\"http://schemas.microsoft.com/powershell/2004/04\">" \
        "<S S=\"Error\">, world!_x000D__x000A_</S></Objs>")
      expect(output.stderr).to eq(@captured_stderr)
    end

    it 'should have output' do
      # TODO: Option to parse CLIXML
      # expect(output.output).to eq("Hello\n, world!")
      expect(output.output).to eq("Hello\n#< CLIXML\r\n<Objs Version=\"1.1.0.1\" " \
        "xmlns=\"http://schemas.microsoft.com/powershell/2004/04\">" \
        "<S S=\"Error\">, world!_x000D__x000A_</S></Objs>")
    end
  end

  describe 'non-ascii encoding' do
    subject(:output) { @winrm.powershell('echo "1234-äöü"') }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/1234-äöü/) }
  end

  # default
  describe 'use 64bit powershell console' do
    subject(:output) { @winrm.powershell('[IntPtr]::size') }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/8/) }
  end

  describe 'use 32bit powershell console' do
    subject(:output) { @winrm.powershell('[IntPtr]::size', :use_32bit => true) }
    it { should have_exit_code 0 }
    it { should have_stdout_match(/4/) }
  end

  describe 'run commands up to ~3000 chars length' do
    cmd = '0' * 3048
    subject(:output) { @winrm.powershell(cmd) }
    it { should have_exit_code 0 }
  end

  describe 'fails if running commands longer than length limit' do
    cmd = '0' * 3049
    subject(:output) { @winrm.powershell(cmd) }
    it { should have_exit_code 1 }
  end

  describe 'if using copy_and_run, we can circumvent this length limit' do
    cmd = '0' * 4000
    subject(:output) { @winrm.copy_and_run_powershell_script(cmd) }
    it { should have_exit_code 0 }
  end

  describe 'capturing stdout, stderr and exit code when using copy_and_run' do
    script = <<-eos
    Write-Host 'Hello'
    $host.ui.WriteErrorLine('Goodbye')
    exit 10
    eos
    subject(:output) { @winrm.copy_and_run_powershell_script(script) }
    it { should have_exit_code 10 }
    it { should have_stdout_match /Hello/ }
    it { should have_stderr_match /Goodbye/ }
  end
end
