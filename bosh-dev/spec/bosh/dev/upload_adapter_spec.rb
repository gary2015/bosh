require 'spec_helper'

require 'bosh/dev/upload_adapter'

module Bosh::Dev
  describe UploadAdapter do
    let(:adapter) { UploadAdapter.new }

    let(:aws_access_key_id) { 'default fake access key' }
    let(:aws_secret_access_key) { 'default fake secret key' }

    let(:fog_storage) { Fog::Storage.new(
      provider: 'AWS',
      aws_access_key_id: aws_access_key_id,
      aws_secret_access_key: aws_secret_access_key)
    }

    before do
      Fog.mock!
      Fog::Mock.reset
      ENV.stub(to_hash: {
        'AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT' => aws_access_key_id,
        'AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT' => aws_secret_access_key,
      })
    end

    describe '#upload' do
      let(:bucket_name) { 'fake_bucket_name' }
      let(:key) { 'fake_key.yml' }
      let(:body) { 'fake file body' }
      let(:public) { false }

      it 'uploads the file to remote path' do
        fog_storage.directories.create(key: bucket_name)

        adapter.upload(bucket_name: bucket_name, key: key, body: body, public: public)

        expect(fog_storage.directories.get(bucket_name).files.get(key).body).to eq(body)
      end

      it 'raises an error if the bucket does not exist' do
        expect {
          adapter.upload(bucket_name: bucket_name, key: key, body: body, public: public)
        }.to raise_error("bucket 'fake_bucket_name' not found")
      end

    end
  end
end
