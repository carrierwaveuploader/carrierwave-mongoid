# encoding: utf-8
require 'spec_helper'

shared_examples_for "a GridFS connection" do
  describe '#store!' do
    before do
      allow(@uploader).to receive(:store_path).and_return('uploads/bar.txt')
      @grid_fs_file = @storage.store!(@file)
    end

    it "should upload the file to gridfs" do
      expect(@grid['uploads/bar.txt'].data).to eq 'this is stuff'
    end

    it "should upload the file to gridfs" do
      expect(@grid['uploads/bar.txt'].data).to eq 'this is stuff'
    end

    it "should have the same path that it was stored as" do
      expect(@grid_fs_file.path).to eq 'uploads/bar.txt'
    end

    it "should read the contents of the file" do
      expect(@grid_fs_file.read).to eq "this is stuff"
    end

    it "should not have a URL" do
      expect(@grid_fs_file.url).to be_nil
    end

    it "should be deletable" do
      @grid_fs_file.delete
      expect(@grid['uploads/bar.txt']).to be_nil
    end

    it "should store the content type on GridFS" do
      expect(@grid_fs_file.content_type).to eq 'text/plain'
    end

    it "should have a file length" do
      expect(@grid_fs_file.file_length).to eq 13
    end

    it "should have a file md5" do
      expect(@grid_fs_file.md5).to eq 'bf8456578232907ce3136ba776e1a40d'
    end
  end

  describe '#retrieve!' do
    before do
      @grid.clear
      @grid['uploads/bar.txt'] = StringIO.new('A test, 1234')
      allow(@uploader).to receive(:store_path).with('bar.txt').and_return('uploads/bar.txt')
      @grid_fs_file = @storage.retrieve!('bar.txt')
    end

    it "should retrieve the file contents from gridfs" do
      expect(@grid_fs_file.read.chomp).to eq "A test, 1234"
    end

    it "should have the same path that it was stored as" do
      expect(@grid_fs_file.path).to eq 'uploads/bar.txt'
    end

    it "should not have a URL unless access_url is set" do
      expect(@grid_fs_file.url).to be_nil
    end

    it "should return a relative URL path if access_url is set to the root path" do
      allow(@uploader).to receive(:grid_fs_access_url).and_return("/")
      expect(@grid_fs_file.url).to eq "/uploads/bar.txt"
    end

    it "should return a URL path if access_url is set to a file path" do
      allow(@uploader).to receive(:grid_fs_access_url).and_return("/image/show")
      expect(@grid_fs_file.url).to eq "/image/show/uploads/bar.txt"
    end

    it "should return an absolute URL if access_url is set to an absolute URL" do
      allow(@uploader).to receive(:grid_fs_access_url).and_return("http://example.com/images/")
      expect(@grid_fs_file.url).to eq "http://example.com/images/uploads/bar.txt"
    end

    it "should be deletable" do
      @grid_fs_file.delete
      expect(@grid['uploads/bar.txt']).to be_nil
    end
  end

  describe '#retrieve! on a store_dir with leading slash' do
    before do
      allow(@uploader).to receive(:store_path).with('bar.txt').and_return('/uploads/bar.txt')
      @grid_fs_file = @storage.retrieve!('bar.txt')
    end

    it "should return a relative URL path if access_url is set to the root path" do
      allow(@uploader).to receive(:grid_fs_access_url).and_return("/")
      expect(@grid_fs_file.url).to eq "/uploads/bar.txt"
    end
  end

end

describe CarrierWave::Storage::GridFS do

  before do
    @uploader = double('an uploader')
    allow(@uploader).to receive(:grid_fs_access_url).and_return(nil)
  end

  context "when reusing an existing connection manually" do
    before do
      allow(@uploader).to receive(:grid_fs_connection).and_return(@database)

      @grid = ::Mongoid::GridFs

      @storage = CarrierWave::Storage::GridFS.new(@uploader)
      @file = stub_tempfile('test.jpg', 'application/xml')
    end

    it_should_behave_like "a GridFS connection"

    # Calling #recreate_versions! on uploaders has been known to fail on
    # remotely hosted files. This is due to a variety of issues, but this test
    # makes sure that there's no unnecessary errors during the process
    describe "#recreate_versions!" do
      before do
        @uploader_class = Class.new(CarrierWave::Uploader::Base)
        @uploader_class.class_eval{
          include CarrierWave::MiniMagick
          storage :grid_fs

          process :resize_to_fit => [10, 10]
        }

        @versioned = @uploader_class.new

        @versioned.store! File.open(file_path('portrait.jpg'))
      end

      after do
        FileUtils.rm_rf(public_path)
      end

      it "recreates versions stored remotely without error" do
        expect { @versioned.recreate_versions! }.not_to raise_error
        expect(@versioned).to be_present
      end
    end

    describe "resize_to_fill" do
      before do
        @uploader_class = Class.new(CarrierWave::Uploader::Base)
        @uploader_class.class_eval{
          include CarrierWave::MiniMagick
          storage :grid_fs
          process resize_to_fill: [200, 200]
        }

        @versioned = @uploader_class.new

        @file = File.open(file_path('portrait.jpg'))
      end

      after do
        FileUtils.rm_rf(public_path)
      end

      it "resizes the file with out error" do
        expect { @versioned.store! @file }.not_to raise_error
      end
    end

    describe "#clean_cache!" do
      before do
        @uploader_class = Class.new(CarrierWave::Uploader::Base)
        @uploader_class.class_eval{
          storage :grid_fs
        }

        file = File.open(file_path('portrait.jpg'))
        @filenames = [Time.now.utc - 3700, Time.now.utc - 3610, Time.now.utc - 3590].map do |time|
          "#{time.to_i}-1234-5678-9000/portrait.jpg"
        end
        @filenames << "not-a-cache/portrait.jpg"
        @filenames.each { |filename| @grid[filename] = file }
      end

      it "cleans old cache files" do
        @uploader_class.clean_cached_files!(3600)
        expect(@grid.namespace.file_model.all.to_a.map(&:filename)).to eq @filenames[2..3]
      end
    end if CarrierWave::VERSION >= '2'
  end

  after do
    @grid.clear
  end
end
