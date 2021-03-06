require 'spec_helper'

require 'bosh/dev/stemcell_rake_methods'

module Bosh::Dev
  describe StemcellRakeMethods do
    let(:env) { {} }
    let(:shell) { instance_double('Bosh::Dev::Shell') }
    let(:stemcell_rake_methods) { StemcellRakeMethods.new(env, shell) }

    describe '#default_options' do
      let(:default_disk_size) { 2048 }

      context 'it is not given an infrastructure' do
        it 'dies' do
          STDERR.should_receive(:puts).with('Please specify target infrastructure (vsphere, aws, openstack)')
          stemcell_rake_methods.should_receive(:exit).with(1).and_raise(SystemExit)

          expect {
            stemcell_rake_methods.default_options({})
          }.to raise_error(SystemExit)
        end
      end

      context 'it is not given an unknown infrastructure' do
        it 'dies' do
          expect {
            stemcell_rake_methods.default_options(infrastructure: 'fake')
          }.to raise_error(RuntimeError, /Unknown infrastructure: fake/)
        end
      end

      shared_examples_for 'setting default stemcells environment values' do
        let(:env) do
          {
            'OVFTOOL' => 'fake_ovf_tool_path',
            'STEMCELL_HYPERVISOR' => 'fake_stemcell_hypervisor',
            'STEMCELL_NAME' => 'fake_stemcell_name',
            'UBUNTU_ISO' => 'fake_ubuntu_iso',
            'UBUNTU_MIRROR' => 'fake_ubuntu_mirror',
            'TW_LOCAL_PASSPHRASE' => 'fake_tripwire_local_passphrase',
            'TW_SITE_PASSPHRASE' => 'fake_tripwire_site_passphrase',
            'RUBY_BIN' => 'fake_ruby_bin',
          }
        end

        it 'sets default values for options based in hash' do
          result = stemcell_rake_methods.default_options(infrastructure: infrastructure)

          expect(result['system_parameters_infrastructure']).to eq(infrastructure)
          expect(result['stemcell_name']).to eq('fake_stemcell_name')
          expect(result['stemcell_infrastructure']).to eq(infrastructure)
          expect(result['stemcell_hypervisor']).to eq('fake_stemcell_hypervisor')
          expect(result['bosh_protocol_version']).to eq('1')
          expect(result['UBUNTU_ISO']).to eq('fake_ubuntu_iso')
          expect(result['UBUNTU_MIRROR']).to eq('fake_ubuntu_mirror')
          expect(result['TW_LOCAL_PASSPHRASE']).to eq('fake_tripwire_local_passphrase')
          expect(result['TW_SITE_PASSPHRASE']).to eq('fake_tripwire_site_passphrase')
          expect(result['ruby_bin']).to eq('fake_ruby_bin')
          expect(result['bosh_release_src_dir']).to match(%r{/release/src/bosh})
          expect(result['bosh_agent_src_dir']).to match(/bosh_agent/)
          expect(result['image_create_disk_size']).to eq(default_disk_size)
        end

        context 'when RUBY_BIN is not set' do
          let(:env) do
            {
              'OVFTOOL' => 'fake_ovf_tool_path',
              'STEMCELL_HYPERVISOR' => 'fake_stemcell_hypervisor',
              'STEMCELL_NAME' => 'fake_stemcell_name',
              'UBUNTU_ISO' => 'fake_ubuntu_iso',
              'UBUNTU_MIRROR' => 'fake_ubuntu_mirror',
              'TW_LOCAL_PASSPHRASE' => 'fake_tripwire_local_passphrase',
              'TW_SITE_PASSPHRASE' => 'fake_tripwire_site_passphrase',
            }
          end

          before do
            RbConfig::CONFIG.stub(:[]).with('bindir').and_return('/a/path/to/')
            RbConfig::CONFIG.stub(:[]).with('ruby_install_name').and_return('ruby')
          end

          it 'uses the RbConfig values' do
            result = stemcell_rake_methods.default_options(infrastructure: infrastructure)
            expect(result['ruby_bin']).to eq('/a/path/to/ruby')
          end
        end

        it 'sets the disk_size to 2048MB unless the user requests otherwise' do
          result = stemcell_rake_methods.default_options(infrastructure: infrastructure)

          expect(result['image_create_disk_size']).to eq(default_disk_size)
        end

        it 'allows user to override default disk_size' do
          result = stemcell_rake_methods.default_options(infrastructure: infrastructure, disk_size: 1234)

          expect(result['image_create_disk_size']).to eq(1234)
        end
      end

      context 'it is given an infrastructure' do
        context 'when infrastruture is aws' do
          let(:infrastructure) { 'aws' }

          it_behaves_like 'setting default stemcells environment values'

          context 'when STEMCELL_HYPERVISOR is not set' do
            it 'uses "xen"' do
              result = stemcell_rake_methods.default_options(infrastructure: infrastructure)
              expect(result['stemcell_hypervisor']).to eq('xen')
            end
          end
        end

        context 'when infrastruture is vsphere' do
          let(:infrastructure) { 'vsphere' }

          it_behaves_like 'setting default stemcells environment values'

          context 'when STEMCELL_HYPERVISOR is not set' do
            let(:env) { { 'OVFTOOL' => 'fake_ovf_tool_path' } }

            it 'uses "esxi"' do
              result = stemcell_rake_methods.default_options(infrastructure: infrastructure)
              expect(result['stemcell_hypervisor']).to eq('esxi')
            end
          end

          context 'if you have OVFTOOL set in the environment' do
            let(:env) { { 'OVFTOOL' => 'fake_ovf_tool_path' } }

            it 'sets image_vsphere_ovf_ovftool_path' do
              result = stemcell_rake_methods.default_options(infrastructure: 'vsphere')
              expect(result['image_vsphere_ovf_ovftool_path']).to eq('fake_ovf_tool_path')
            end
          end
        end

        context 'when infrastructure is openstack' do
          let(:infrastructure) { 'openstack' }
          let(:default_disk_size) { 10240 }

          it_behaves_like 'setting default stemcells environment values'

          context 'when STEMCELL_HYPERVISOR is not set' do
            it 'uses "kvm"' do
              result = stemcell_rake_methods.default_options(infrastructure: infrastructure)
              expect(result['stemcell_hypervisor']).to eq('kvm')
            end
          end

          it 'increases default disk_size from 2048 to 10240 because of the lack of ephemeral disk' do
            result = stemcell_rake_methods.default_options(infrastructure: 'openstack')

            expect(result['image_create_disk_size']).to eq(10240)
          end

          it 'still allows user to force a specific disk_size' do
            result = stemcell_rake_methods.default_options(infrastructure: 'openstack', disk_size: 1234)

            expect(result['image_create_disk_size']).to eq(1234)
          end
        end
      end
    end

    describe '#bosh_micro_options' do
      let(:manifest) { 'fake_manifest' }
      let(:tarball) { 'fake_tarball' }
      let(:bosh_micro_options) { stemcell_rake_methods.bosh_micro_options(manifest, tarball) }

      it 'returns a valid hash' do
        expect(bosh_micro_options[:bosh_micro_enabled]).to eq('yes')
        expect(bosh_micro_options[:bosh_micro_package_compiler_path]).to match(/\bpackage_compiler\b/)
        expect(bosh_micro_options[:bosh_micro_manifest_yml_path]).to eq('fake_manifest')
        expect(bosh_micro_options[:bosh_micro_release_tgz_path]).to eq('fake_tarball')
      end
    end

    describe '#build' do
      include FakeFS::SpecHelpers

      let(:pid) { 99999 }
      let(:root_dir) { "/var/tmp/bosh/bosh_agent-#{Bosh::Agent::VERSION}-#{pid}" }
      let(:build_dir) { File.join(root_dir, 'build') }
      let(:work_dir) { File.join(root_dir, 'work') }
      let(:etc_dir) { File.join(build_dir, 'etc') }
      let(:settings_file) { File.join(etc_dir, 'settings.bash') }
      let(:spec_file) { File.join(build_dir, 'spec', "#{spec}.spec") }
      let(:build_script) { File.join(build_dir, 'bin', 'build_from_spec.sh') }

      let(:spec) { 'dave' }
      let(:options) { { 'hello' => 'world' } }

      before do
        shell.stub(:run)
        stemcell_rake_methods.stub(:puts)
        Process.stub(pid: pid)
        FileUtils.stub(:cp_r).with([], build_dir, preserve: true) do
          FileUtils.mkdir_p etc_dir
          FileUtils.touch settings_file
        end
      end

      it 'creates a base directory for stemcell creation' do
        expect {
          stemcell_rake_methods.build(spec, options)
        }.to change { Dir.exists?(root_dir) }.from(false).to(true)
      end

      it 'creates a build directory for stemcell creation' do
        expect {
          stemcell_rake_methods.build(spec, options)
        }.to change { Dir.exists?(build_dir) }.from(false).to(true)
      end

      it 'copies the stemcell_builder code into the build directory' do
        FileUtils.should_receive(:cp_r).with([], build_dir, preserve: true) do
          FileUtils.mkdir_p etc_dir
          FileUtils.touch File.join(etc_dir, 'settings.bash')
        end
        stemcell_rake_methods.build(spec, options)
      end

      it 'creates a work directory for stemcell creation chroot' do
        expect {
          stemcell_rake_methods.build(spec, options)
        }.to change { Dir.exists?(work_dir) }.from(false).to(true)
      end

      context 'when the user sets their own WORK_PATH' do
        let(:env) { { 'WORK_PATH' => '/aight' } }

        it 'creates a work directory for stemcell creation chroot' do
          expect {
            stemcell_rake_methods.build(spec, options)
          }.to change { Dir.exists?('/aight') }.from(false).to(true)
        end
      end

      it 'writes a settings file into the build directory' do
        stemcell_rake_methods.build(spec, options)
        expect(File.read(settings_file)).to match(/hello=world/)
      end

      context 'when the user does not set proxy environment variables' do
        it 'runs the stemcell builder with no environment variables set' do
          shell.should_receive(:run).with("sudo env  #{build_script} #{work_dir} #{spec_file} #{settings_file}")
          stemcell_rake_methods.build(spec, options)
        end
      end

      context 'when the uses sets proxy environment variables' do
        let(:env) { { 'HTTP_PROXY' => 'nice_proxy', 'no_proxy' => 'naughty_proxy' } }

        it 'maintains current user proxy env vars through the shell sudo call' do
          shell.should_receive(:run).with("sudo env HTTP_PROXY='nice_proxy' no_proxy='naughty_proxy' #{build_script} #{work_dir} #{spec_file} #{settings_file}")
          stemcell_rake_methods.build(spec, options)
        end
      end

      context 'when the uses sets a BUILD_PATH environment variable' do
        let(:root_dir) { 'TEST_ROOT_DIR' }
        let(:env) { { 'BUILD_PATH' => root_dir } }

        it 'passes through BUILD_PATH environment variables correctly' do
          shell.should_receive(:run).with("sudo env  #{build_script} #{work_dir} #{spec_file} #{settings_file}")
          stemcell_rake_methods.build(spec, options)
        end
      end
    end
  end
end