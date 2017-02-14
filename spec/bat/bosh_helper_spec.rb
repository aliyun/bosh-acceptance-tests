require 'spec_helper'
require 'bat/env'
require 'bat/bosh_runner'
require 'bat/bosh_helper'

describe Bat::BoshHelper do
  subject(:bosh_helper) do
    Class.new { include Bat::BoshHelper }.new
  end

  before { bosh_helper.instance_variable_set('@bosh_runner', bosh_runner) }
  let(:bosh_runner) { instance_double('Bat::BoshRunner') }

  before { bosh_helper.instance_variable_set('@bosh_runner', bosh_runner) }
  let(:bosh_runner) { instance_double('Bat::BoshRunner') }

  before { stub_const('ENV', {}) }

  before { bosh_helper.instance_variable_set('@logger', Logger.new('/dev/null')) }

  describe '#ssh_options' do
    let(:env) { instance_double('Bat::Env') }
    before { bosh_helper.instance_variable_set('@env', env) }
    before { allow(env).to receive(:vcap_password).and_return('fake_password') }

    context 'when both env var BAT_VCAP_PRIVATE_KEY is set' do
      before { allow(env).to receive(:vcap_private_key).and_return('fake_private_key') }
      it { expect(bosh_helper.ssh_options).to eq(private_key: 'fake_private_key', password: 'fake_password') }
    end

    context 'when BAT_VCAP_PRIVATE_KEY is not set in env' do
      before { allow(env).to receive(:vcap_private_key).and_return(nil) }
      it { expect(bosh_helper.ssh_options).to eq(password: 'fake_password', private_key: nil) }
    end
  end

  describe '#wait_for_instance_state' do
    # rubocop:disable LineLength
    let(:bosh_instances_output_with_jesse_in_running_state) { <<-'OUTPUT' }
{
    "Tables": [
        {
            "Content": "instances",
            "Header": [
                "Instance",
                "Process State",
                "AZ",
                "IPs",
                "State",
                "VM CID",
                "VM Type",
                "Disk CIDs",
                "Agent ID",
                "Index",
                "Resurrection\nPaused",
                "Bootstrap",
                "Ignore"
            ],
            "Rows": [
                [
                    "jessez/29ae97ec-3106-450b-a848-98cb3b25d86f",
                    "running",
                    "z3",
                    "10.20.30.1",
                    "started",
                    "i-cid",
                    "default",
                    "daafa7a0-1df2-4482-67e4-6ec795c76434",
                    "fake-agent-id",
                    "0",
                    "false",
                    "false",
                    "false"
                ],
                [
                    "uaa_z1/a3cebb2f-2553-46e3-aa0d-d2075cd08760",
                    "running",
                    "z1",
                    "10.50.91.2",
                    "started",
                    "i-24cb6153",
                    "default",
                    "df5de774-8a0c-4e4c-7418-93e425de3aa2",
                    "da74e0d8-d2a6-4b2d-904a-b2f0e3dacc49",
                    "0",
                    "false",
                    "false",
                    "false"
                ]
            ],
            "Notes": null
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment '0.0.0.0' as client 'admin'",
        "Task 4",
        ". Done",
        "Succeeded"
    ]
}
OUTPUT

    let(:bosh_instances_output_with_jesse_in_unresponsive_state) { <<'OUTPUT' }
{
    "Tables": [
        {
            "Content": "instances",
            "Header": [
                "Instance",
                "Process State",
                "AZ",
                "IPs",
                "State",
                "VM CID",
                "VM Type",
                "Disk CIDs",
                "Agent ID",
                "Index",
                "Resurrection\nPaused",
                "Bootstrap",
                "Ignore"
            ],
            "Rows": [
                [
                    "jessez/29ae97ec-3106-450b-a848-98cb3b25d86f",
                    "unresponsive agent",
                    "z3",
                    "10.20.30.1",
                    "started",
                    "i-cid",
                    "default",
                    "daafa7a0-1df2-4482-67e4-6ec795c76434",
                    "fake-agent-id",
                    "0",
                    "false",
                    "false",
                    "false"
                ],
                [
                    "uaa_z1/a3cebb2f-2553-46e3-aa0d-d2075cd08760",
                    "running",
                    "z1",
                    "10.50.91.2",
                    "started",
                    "i-24cb6153",
                    "default",
                    "df5de774-8a0c-4e4c-7418-93e425de3aa2",
                    "da74e0d8-d2a6-4b2d-904a-b2f0e3dacc49",
                    "0",
                    "false",
                    "false",
                    "false"
                ]
            ],
            "Notes": null
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment '0.0.0.0' as client 'admin'",
        "Task 4",
        ". Done",
        "Succeeded"
    ]
}
OUTPUT
    let(:bosh_instances_output_without_jesse) { <<'OUTPUT' }
{
    "Tables": [
        {
            "Content": "instances",
            "Header": [
                "Instance",
                "Process State",
                "AZ",
                "IPs",
                "State",
                "VM CID",
                "VM Type",
                "Disk CIDs",
                "Agent ID",
                "Index",
                "Resurrection\nPaused",
                "Bootstrap",
                "Ignore"
            ],
            "Rows": [
                [
                    "uaa_z1/a3cebb2f-2553-46e3-aa0d-d2075cd08760",
                    "running",
                    "z1",
                    "10.50.91.2",
                    "started",
                    "i-24cb6153",
                    "default",
                    "df5de774-8a0c-4e4c-7418-93e425de3aa2",
                    "da74e0d8-d2a6-4b2d-904a-b2f0e3dacc49",
                    "0",
                    "false",
                    "false",
                    "false"
                ]
            ],
            "Notes": null
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment '0.0.0.0' as client 'admin'",
        "Task 4",
        ". Done",
        "Succeeded"
    ]
}
OUTPUT
      # rubocop:enable LineLength
    context 'when "instance" in expected state' do
      before do
        fake_result = double('fake bosh exec result', output: bosh_instances_output_with_jesse_in_running_state)
        allow(bosh_runner).to receive(:bosh).with('instances --details').and_return(fake_result)
      end

      it 'returns the instance details' do
        expect(bosh_helper.wait_for_instance_state('jessez', '0', 'running', 0)).to(eq(
          instance: 'jessez/29ae97ec-3106-450b-a848-98cb3b25d86f',
          process_state: 'running',
          ips: '10.20.30.1',
          vm_cid: 'i-cid',
          vm_type: 'default',
          ignore: 'false',
          agent_id: 'fake-agent-id',
          resurrection_paused: 'false',
          az: 'z3',
          bootstrap: 'false',
          disk_cids: 'daafa7a0-1df2-4482-67e4-6ec795c76434',
          index: '0',
          state: 'started',
        ))
      end

      context 'when the director is using legacy instance names' do
    let(:bosh_instances_output_with_jesse_in_running_state) { <<'OUTPUT' }
{
    "Tables": [
        {
            "Content": "instances",
            "Header": [
                "Instance",
                "Process State",
                "AZ",
                "IPs",
                "State",
                "VM CID",
                "VM Type",
                "Disk CIDs",
                "Agent ID",
                "Index",
                "Resurrection\nPaused",
                "Bootstrap",
                "Ignore"
            ],
            "Rows": [
                [
                    "jessez/0 (29ae97ec-3106-450b-a848-98cb3b25d86f)",
                    "running",
                    "z3",
                    "10.20.30.1",
                    "started",
                    "i-cid",
                    "default",
                    "daafa7a0-1df2-4482-67e4-6ec795c76434",
                    "fake-agent-id",
                    "0",
                    "false",
                    "false",
                    "false"
                ],
                [
                    "uaa_z1/0 (a3cebb2f-2553-46e3-aa0d-d2075cd08760)",
                    "running",
                    "z1",
                    "10.50.91.2",
                    "started",
                    "i-24cb6153",
                    "default",
                    "df5de774-8a0c-4e4c-7418-93e425de3aa2",
                    "da74e0d8-d2a6-4b2d-904a-b2f0e3dacc49",
                    "0",
                    "false",
                    "false",
                    "false"
                ]
            ],
            "Notes": null
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment '0.0.0.0' as client 'admin'",
        "Task 4",
        ". Done",
        "Succeeded"
    ]
}
OUTPUT

        it 'returns the instance details' do
          expect(bosh_helper.wait_for_instance_state('jessez', '0', 'running', 0)).to(eq(
            instance: 'jessez/0 (29ae97ec-3106-450b-a848-98cb3b25d86f)',
            process_state: 'running',
            ips: '10.20.30.1',
            vm_cid: 'i-cid',
            vm_type: 'default',
            ignore: 'false',
            agent_id: 'fake-agent-id',
            resurrection_paused: 'false',
            az: 'z3',
            bootstrap: 'false',
            disk_cids: 'daafa7a0-1df2-4482-67e4-6ec795c76434',
            index: '0',
            state: 'started',
          ))
        end
      end
    end

    context 'when "instance" in different state' do
      before do
        fake_result = double('fake bosh exec result', output: bosh_instances_output_with_jesse_in_unresponsive_state)
        allow(bosh_runner).to receive(:bosh).with('instances --details').and_return(fake_result)
      end

      it 'returns nil' do
        expect{bosh_helper.wait_for_instance_state('jessez', '0', 'running', 0)}.to raise_error
      end
    end

    context 'when "instance" is missing in "bosh instances" output' do
      before do
        fake_result = double('fake bosh exec result', output: bosh_instances_output_without_jesse)
        allow(bosh_runner).to receive(:bosh).with('instances --details').and_return(fake_result)
      end

      it 'returns nil' do
        expect{bosh_helper.wait_for_instance_state('jessez', '0', 'running', 0)}.to raise_error
      end
    end

    context 'when "instance" was not in desired state at first, but appear after 4 retries' do
      let(:bad_result) { double('fake exec result', output: bosh_instances_output_with_jesse_in_unresponsive_state) }
      let(:good_result) { double('fake good exec result', output: bosh_instances_output_with_jesse_in_running_state) }
      before do
        allow(bosh_runner).to receive(:bosh).with('instances --details').and_return(
            bad_result,
            bad_result,
            bad_result,
            good_result,
        )
      end

      it 'returns the instance details' do
        expect(bosh_helper.wait_for_instance_state('jessez', '0', 'running', 0)).to(eq(
          instance: 'jessez/29ae97ec-3106-450b-a848-98cb3b25d86f',
          process_state: 'running',
          ips: '10.20.30.1',
          vm_cid: 'i-cid',
          vm_type: 'default',
          ignore: 'false',
          agent_id: 'fake-agent-id',
          resurrection_paused: 'false',
          az: 'z3',
          bootstrap: 'false',
          disk_cids: 'daafa7a0-1df2-4482-67e4-6ec795c76434',
          index: '0',
          state: 'started',
        ))
      end
    end
  end
end
