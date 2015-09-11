# encoding: utf-8
require 'spec_helper'

require 'carrierwave/mongoid'

def reset_mongo_class(uploader = MongoUploader)
  define_mongo_class('MongoUser') do
    include Mongoid::Document
    store_in :collection => 'users'
    field :folder, :default => ''
    mount_uploader :image, uploader
  end
end

def define_mongo_class(class_name, &block)
  Object.send(:remove_const, class_name) rescue nil
  klass = Object.const_set(class_name, Class.new)
  klass.class_eval(&block)
  klass
end

class MongoUploader < CarrierWave::Uploader::Base; end
class AnotherMongoUploader < CarrierWave::Uploader::Base; end

class IntegrityErrorUploader < CarrierWave::Uploader::Base
  process :monkey
  def monkey
    raise CarrierWave::IntegrityError
  end
  def extension_white_list
    %w(jpg)
  end
end

class ProcessingErrorUploader < CarrierWave::Uploader::Base
  process :monkey
  def monkey
    raise CarrierWave::ProcessingError
  end
  def extension_white_list
    %w(jpg)
  end
end


describe CarrierWave::Mongoid do

  after do
    MongoUser.collection.drop if MongoUser.count > 0
  end

  describe '#image' do

    context "when nothing is assigned" do

      before do
        mongo_user_klass = reset_mongo_class
        @document = mongo_user_klass.new
      end

      it "returns a blank uploader" do
        @document.image.should be_blank
      end

    end

    context "when an empty string is assigned" do

      before do
        mongo_user_klass = reset_mongo_class
        @document = mongo_user_klass.new(:image => "")
        @document.save
      end

      it "returns a blank uploader" do
        @saved_doc = MongoUser.first
        @saved_doc.image.should be_blank
      end

    end

    context "when a filename is saved in the database" do

      before do
        mongo_user_klass = reset_mongo_class
        @document = mongo_user_klass.new
        # should retrieve a file from the storage if a value is stored in the database
        @document[:image] = "test.jpg" # NOT @document.image = 'text.jpg'
        @document.save
        @doc = MongoUser.first
      end

      it "returns an uploader" do
        @doc.image.should be_an_instance_of(MongoUploader)
      end

      it "sets the path to the store directory" do
        @doc.image.current_path.should == public_path('uploads/test.jpg')
      end

      it "should return valid JSON when to_json is called when image is nil" do
        @doc[:image] = nil
        hash = JSON.parse(@doc.to_json)
        hash.keys.should include("image")
        hash["image"].keys.should include("url")
        hash["image"]["url"].should be_nil
      end

      it "should return valid JSON when to_json is called when image is present" do
        @doc[:image] = 'test.jpeg'
        @doc.save!
        @doc.reload

        JSON.parse(@doc.to_json)["image"].should == {"url" => "/uploads/test.jpeg"}
      end

      it "should return valid JSON when to_json is called on a collection containing uploader from a model" do
        @doc[:image] = 'test.jpeg'
        @doc.save!
        @doc.reload

        JSON.parse({:data => @doc.image}.to_json).should == {"data"=>{"image"=>{"url"=>"/uploads/test.jpeg"}}}
      end

      it "should respect options[:only] when passed to to_json for the serializable hash" do
        @doc[:image] = 'test.jpeg'
        @doc.save!
        @doc.reload
        JSON.parse(@doc.to_json({:only => [:_id]})).should == {"_id" => @doc.id.as_json}
      end

      it "should respect options[:except] when passed to to_json for the serializable hash" do
        @doc[:image] = 'test.jpeg'
        @doc.save!
        @doc.reload

        JSON.parse(@doc.to_json({:except => [:_id, :image]})).should == {"folder" => ""}
      end

    end

  end

  describe '#image=' do

    before do
      mongo_user_klass = reset_mongo_class
      @doc = mongo_user_klass.new
    end

    context "when nil is assigned" do

      it "does not set the value" do
        @doc.image = nil
        @doc.image.should be_blank
      end

    end

    context "when an empty string is assigned" do

      it "does not set the value" do
        @doc.image = ''
        @doc.image.should be_blank
      end

    end

    context "when a file is assigned" do

      it "should cache a file" do
        @doc.image = stub_file('test.jpeg')
        @doc.image.should be_an_instance_of(MongoUploader)
      end

      it "should write nothing to the database, to prevent overriden filenames to fail because of unassigned attributes" do
        @doc[:image].should be_nil
      end

      it "should copy a file into into the cache directory" do
        @doc.image = stub_file('test.jpeg')
        @doc.image.current_path.should =~ /^#{public_path('uploads\/tmp')}/
      end

    end

    context 'when validating integrity' do
      before do
        mongo_user_klass = reset_mongo_class(IntegrityErrorUploader)
        @doc = mongo_user_klass.new
        @doc.image = stub_file('test.jpg')
      end

      it "should make the document invalid when an integrity error occurs" do
        @doc.should_not be_valid
      end

      it "should use I18n for integrity error messages" do
        translations = { mongoid: { errors: { messages: { carrierwave_integrity_error: 'is not of an allowed file type' }}}}
        change_locale_and_store_translations(:en, translations) do
          @doc.valid?
          @doc.errors[:image].should == ['is not of an allowed file type']
        end

        translations = { mongoid: { errors: { messages: { carrierwave_integrity_error: 'tipo de imagem não permitido.' }}}}
        change_locale_and_store_translations(:pt, translations) do
          @doc.valid?
          @doc.errors[:image].should == ['tipo de imagem não permitido.']
        end
      end
    end

    context 'when validating processing' do
      before do
        mongo_user_klass = reset_mongo_class(ProcessingErrorUploader)
        @doc = mongo_user_klass.new
        @doc.image = stub_file('test.jpg')
      end

      it "should make the document invalid when a processing error occurs" do
        @doc.should_not be_valid
      end

      it "should use I18n for processing error messages" do
        translations = { mongoid: { errors: { messages: { carrierwave_processing_error: 'failed to be processed' }}}}
        change_locale_and_store_translations(:en, translations) do
          @doc.valid?
          @doc.errors[:image].should == ['failed to be processed']
        end

        translations = { mongoid: { errors: { messages: { carrierwave_processing_error: 'falha ao processar imagem.' }}}}
        change_locale_and_store_translations(:pt, translations) do
          @doc.valid?
          @doc.errors[:image].should == ['falha ao processar imagem.']
        end
      end
    end

  end

  describe '#remove_image=' do
    before do
      mongo_user_klass = reset_mongo_class
      @doc = mongo_user_klass.new
    end

    it "treats true argument such that attribute is marked as changed" do
      @doc.remove_image = true
      @doc.should be_image_changed
    end

    it "treats '1' argument such that attribute is marked as changed" do
      @doc.remove_image = '1'
      @doc.should be_image_changed
    end

    it "treats false argument such that attribute is not marked as changed" do
      @doc.remove_image = false
      @doc.should_not be_image_changed
    end

    it "treats nil argument such that attribute is not marked as changed" do
      @doc.remove_image = nil
      @doc.should_not be_image_changed
    end

    it "treats '0' argument such that attribute is not marked as changed" do
      @doc.remove_image = '0'
      @doc.should_not be_image_changed
    end
  end

  describe "#save" do

    it "after it was initialized with params" do
      doc = reset_mongo_class.new(:image => stub_file('test.jpg'))
      doc.save.should be_truthy
      doc.image.should be_an_instance_of(MongoUploader)
      doc.image.current_path.should == public_path('uploads/test.jpg')
    end

    before do
      mongo_user_klass = reset_mongo_class
      @doc = mongo_user_klass.new
    end

    context "when no file is assigned" do

      it "image is blank" do
        @doc.save.should be_truthy
        @doc.image.should be_blank
      end

    end

    context "when a file is assigned" do

      it "copies the file to the upload directory" do
        @doc.image = stub_file('test.jpg')
        @doc.save.should be_truthy
        @doc.image.should be_an_instance_of(MongoUploader)
        @doc.image.current_path.should == public_path('uploads/test.jpg')
      end

      it "saves the filename in the database" do
        @doc.image = stub_file('test.jpg')
        @doc.save.should be_truthy
        @doc[:image].should == 'test.jpg'
        @doc.image_identifier.should == 'test.jpg'
      end

      context "when remove_image? is true" do

        it "removes the image" do
          @doc.image = stub_file('test.jpeg')
          @doc.save
          @doc.remove_image = true
          @doc.save.should be_truthy
          @doc.reload
          @doc.image.should be_blank
          @doc.image_identifier.should be_blank
        end

      end

      it "should mark image as changed when saving a new image" do
        @doc.image_changed?.should be_falsey
        @doc.image = stub_file("test.jpeg")
        @doc.image_changed?.should be_truthy
        @doc.save
        @doc.reload
        @doc.image_changed?.should be_falsey
        @doc.image = stub_file("test.jpg")
        @doc.image_changed?.should be_truthy
      end

    end

  end

  describe '#update' do

    before do
      mongo_user_klass = reset_mongo_class
      @doc = mongo_user_klass.new
      @doc.image = stub_file('test.jpeg')
      @doc.save
      @doc.reload
    end

    it "replaced it by a file with the same name" do
      @doc.image = stub_file('test.jpeg')
      @doc.save
      @doc.reload
      @doc[:image].should == 'test.jpeg'
      @doc.image_identifier.should == 'test.jpeg'
    end

  end

  describe '#destroy' do

    before do
      mongo_user_klass = reset_mongo_class
      @doc = mongo_user_klass.new
    end

    describe "when file assigned" do

      it "removes the file from the filesystem" do
        @doc.image = stub_file('test.jpeg')
        @doc.save.should be_truthy
        File.exist?(public_path('uploads/test.jpeg')).should be_truthy
        @doc.image.should be_an_instance_of(MongoUploader)
        @doc.image.current_path.should == public_path('uploads/test.jpeg')
        @doc.destroy
        File.exist?(public_path('uploads/test.jpeg')).should be_falsey
      end

    end

    describe "when file is not assigned" do

      it "deletes the instance of MongoUser after save" do
        @doc.save
        MongoUser.count.should eq(1)
        @doc.destroy
      end

      it "deletes the instance of MongoUser after save and then re-looking up the instance" do
        @doc.save
        MongoUser.count.should eq(1)
        @doc = MongoUser.first
        @doc.destroy
      end

    end

  end

  describe '#mount_uploader removing old files' do

    before do
      @uploader = Class.new(MongoUploader)
      @class = reset_mongo_class(@uploader)
      @class.field :foo
      @doc = @class.new
      @doc.image = stub_file('old.jpeg')
      @doc.save.should be_truthy
      File.exists?(public_path('uploads/old.jpeg')).should be_truthy
    end

    after do
      FileUtils.rm_rf(file_path("uploads"))
    end

    describe 'normally' do

      it "should remove old file if old file had a different path" do
        @doc.image = stub_file('new.jpeg')
        @doc.save.should be_truthy
        File.exists?(public_path('uploads/new.jpeg')).should be_truthy
        File.exists?(public_path('uploads/old.jpeg')).should be_falsey
      end

      it "should not remove old file if old file had a different path but config is false" do
        @uploader.stub(:remove_previously_stored_files_after_update).and_return(false)
        @doc.image = stub_file('new.jpeg')
        @doc.save.should be_truthy
        File.exists?(public_path('uploads/new.jpeg')).should be_truthy
        File.exists?(public_path('uploads/old.jpeg')).should be_truthy
      end

      it "should not remove file if old file had the same path" do
        @doc.image = stub_file('old.jpeg')
        @doc.save.should be_truthy
        File.exists?(public_path('uploads/old.jpeg')).should be_truthy
      end

      it "should not remove file if validations fail on save" do
        @class.validate { |r| r.errors.add :textfile, "FAIL!" }
        @doc.image = stub_file('new.jpeg')
        @doc.save.should be_falsey
        File.exists?(public_path('uploads/old.jpeg')).should be_truthy
      end
    end

    describe 'with an overriden filename' do
      before do
        @uploader.class_eval do
          def filename
            model.foo + File.extname(super)
          end
        end

        @doc.image = stub_file('old.jpeg')
        @doc.foo = "test"
        @doc.save.should be_truthy
        File.exists?(public_path('uploads/test.jpeg')).should be_truthy
        @doc.image.read.should == "this is stuff"
      end

      it "should not remove file if old file had the same dynamic path" do
        @doc.image = stub_file('test.jpeg')
        @doc.save.should be_truthy
        File.exists?(public_path('uploads/test.jpeg')).should be_truthy
      end

      it "should remove old file if old file had a different dynamic path" do
        @doc.foo = "new"
        @doc.image = stub_file('test.jpeg')
        @doc.save.should be_truthy
        File.exists?(public_path('uploads/new.jpeg')).should be_truthy
        File.exists?(public_path('uploads/test.jpeg')).should be_falsey
      end
    end

    shared_examples "embedded documents" do
      it "should remove old file if old file had a different path" do
        @embedded_doc.image = stub_file('new.jpeg')
        @embedded_doc.save.should be_truthy
        File.exists?(public_path('uploads/new.jpeg')).should be_truthy
        File.exists?(public_path('uploads/old.jpeg')).should be_falsey
      end

      it "should not remove old file if old file had a different path but config is false" do
        @embedded_doc.image.stub(:remove_previously_stored_files_after_update).and_return(false)
        @embedded_doc.image = stub_file('new.jpeg')
        @embedded_doc.save.should be_truthy
        File.exists?(public_path('uploads/new.jpeg')).should be_truthy
        File.exists?(public_path('uploads/old.jpeg')).should be_truthy
      end

      it "should not remove file if old file had the same path" do
        @embedded_doc.image = stub_file('old.jpeg')
        @embedded_doc.save.should be_truthy
        File.exists?(public_path('uploads/old.jpeg')).should be_truthy
      end

      it "should not remove file if validations fail on save" do
        @embedded_doc_class.validate { |r| r.errors.add :textfile, "FAIL!" }
        @embedded_doc.image = stub_file('new.jpeg')
        @embedded_doc.save.should be_falsey
        File.exists?(public_path('uploads/old.jpeg')).should be_truthy
      end

      it "should not touch parent's dirty attributes" do
        @class.field :title
        @doc.title = "Title"
        @embedded_doc.image = stub_file('new.jpeg')
        @embedded_doc.save.should be_truthy
        @doc.title.should == "Title"
      end
    end

    shared_examples "double embedded documents" do
      it "should remove old file if old file had a different path" do
        @double_embedded_doc.image = stub_file('new.jpeg')
        @double_embedded_doc.save.should be_truthy
        File.exists?(public_path('uploads/new.jpeg')).should be_truthy
        File.exists?(public_path('uploads/old.jpeg')).should be_falsey
      end

      it "should not remove old file if old file had a different path but config is false" do
        @double_embedded_doc.image.stub(:remove_previously_stored_files_after_update).and_return(false)
        @double_embedded_doc.image = stub_file('new.jpeg')
        @double_embedded_doc.save.should be_truthy
        File.exists?(public_path('uploads/new.jpeg')).should be_truthy
        File.exists?(public_path('uploads/old.jpeg')).should be_truthy
      end

      it "should not remove file if old file had the same path" do
        @double_embedded_doc.image = stub_file('old.jpeg')
        @double_embedded_doc.save.should be_truthy
        File.exists?(public_path('uploads/old.jpeg')).should be_truthy
      end

      it "should not remove file if validations fail on save" do
        @double_embedded_doc_class.validate { |r| r.errors.add :textfile, "FAIL!" }
        @double_embedded_doc.image = stub_file('new.jpeg')
        @double_embedded_doc.save.should be_falsey
        File.exists?(public_path('uploads/old.jpeg')).should be_truthy
      end

    end

    describe 'with document embedded as embeds_one' do
      before do
        @embedded_doc_class = define_mongo_class('MongoLocation') do
          include Mongoid::Document
          mount_uploader :image, @uploader
          embedded_in :mongo_user
        end

        @class.class_eval do
          embeds_one :mongo_location
        end

        @doc = @class.new
        @embedded_doc = @doc.build_mongo_location
        @embedded_doc.image = stub_file('old.jpeg')
        @embedded_doc.save.should be_truthy
      end

      include_examples "embedded documents"
    end

    describe 'with document embedded as embeds_one and parent document not matched the default scope' do
      before do
        @embedded_doc_class = define_mongo_class('MongoLocation') do
          include Mongoid::Document
          mount_uploader :image, @uploader
          embedded_in :mongo_user
        end

        @class.class_eval do
          embeds_one :mongo_location
          default_scope ->{ where(:always_false => false) }
        end

        @doc = @class.new
        @embedded_doc = @doc.build_mongo_location
        @embedded_doc.image = stub_file('old.jpeg')
        @embedded_doc.save.should be_truthy
      end

      include_examples "embedded documents"
    end

    describe 'with embedded documents' do
      before do
        @embedded_doc_class = define_mongo_class('MongoLocation') do
          include Mongoid::Document
          mount_uploader :image, @uploader
          embedded_in :mongo_user
        end

        @class.class_eval do
          embeds_many :mongo_locations, cascade_callbacks: true
          accepts_nested_attributes_for :mongo_locations
        end

        @doc = @class.new
        @embedded_doc = @doc.mongo_locations.build
        @embedded_doc.image = stub_file('old.jpeg')
        @embedded_doc.save.should be_truthy
      end

      include_examples "embedded documents"

      it "attaches a new file to an existing document that had no file at first" do
        doc = @class.new
        doc.mongo_locations.build
        doc.save.should be_truthy
        doc.reload

        doc.mongo_locations.first.image = stub_file('test.jpeg')
        doc.save.should be_truthy
        doc.reload

        doc.mongo_locations.first[:image].should == 'test.jpeg'
      end

      it "changes the file" do
        @doc.update_attributes mongo_locations_attributes: { '0' => { _id: @embedded_doc._id, image: stub_file('test.jpeg') } }
        @doc.reload
        @doc.mongo_locations.first[:image].should == 'test.jpeg'
      end

      it "removes a file" do
        @doc.update_attributes mongo_locations_attributes: { '0' => { _id: @embedded_doc._id, remove_image: "1" } }
        @doc.reload
        @doc.mongo_locations.first[:image].should_not be_present
      end

      describe 'with double embedded documents' do

        before do
          @double_embedded_doc_class = define_mongo_class('MongoItem') do
            include Mongoid::Document
            mount_uploader :image, @uploader
            embedded_in :mongo_location
          end

          @embedded_doc_class.class_eval do
            embeds_many :mongo_items
          end

          @doc = @class.new
          @embedded_doc = @doc.mongo_locations.build
          @embedded_doc.image = stub_file('old.jpeg')
          @embedded_doc.save.should be_truthy

          @double_embedded_doc = @embedded_doc.mongo_items.build
          @double_embedded_doc.image = stub_file('old.jpeg')
          @double_embedded_doc.save.should be_truthy
        end

        include_examples "double embedded documents"
      end
    end

    describe 'with embedded documents and parent document not matched the default scope' do
      before do
        @embedded_doc_class = define_mongo_class('MongoLocation') do
          include Mongoid::Document
          mount_uploader :image, @uploader
          embedded_in :mongo_user
        end

        @class.class_eval do
          embeds_many :mongo_locations
          default_scope ->{ where(:always_false => false) }
        end

        @doc = @class.new
        @embedded_doc = @doc.mongo_locations.build
        @embedded_doc.image = stub_file('old.jpeg')
        @embedded_doc.save.should be_truthy
      end

      include_examples "embedded documents"

      describe 'with double embedded documents' do

        before do
          @double_embedded_doc_class = define_mongo_class('MongoItem') do
            include Mongoid::Document
            mount_uploader :image, @uploader
            embedded_in :mongo_location
          end

          @embedded_doc_class.class_eval do
            embeds_many :mongo_items
          end

          @doc = @class.new
          @embedded_doc = @doc.mongo_locations.build
          @embedded_doc.image = stub_file('old.jpeg')
          @embedded_doc.save.should be_truthy

          @double_embedded_doc = @embedded_doc.mongo_items.build
          @double_embedded_doc.image = stub_file('old.jpeg')
          @double_embedded_doc.save.should be_truthy
        end

        include_examples "double embedded documents"
      end
    end

    describe 'with embedded documents and nested attributes' do
      before do
        @embedded_doc_class = define_mongo_class('MongoLocation') do
          include Mongoid::Document
          mount_uploader :image, @uploader
          embedded_in :mongo_user
        end

        @class.class_eval do
          embeds_many :mongo_locations, cascade_callbacks: true
          accepts_nested_attributes_for :mongo_locations
        end

        @doc = @class.new(mongo_locations_attributes: [{image: stub_file("old.jpeg")}])
        @doc.save.should be_truthy
        @embedded_doc = @doc.mongo_locations.first
      end

      it "should set the image on a save" do
        @doc.reload
        @doc.mongo_locations.first.image.path.should match(/old\.jpeg$/)
        @embedded_doc.image.path.should match(/old\.jpeg$/)
      end

      it "should update the image on update_attributes" do
        @doc.update_attributes(mongo_locations_attributes: [{id: @embedded_doc.id, image: stub_file("new.jpeg")}]).should be_truthy
        @doc.reload
        @doc.mongo_locations.first.image.path.should match(/new\.jpeg$/)
        @embedded_doc.image.path.should match(/new\.jpeg$/)
      end
    end
  end

  describe '#mount_uploader removing old files with versions' do

    before do
      @uploader = Class.new(MongoUploader)
      @uploader.version :thumb
      @class = reset_mongo_class(@uploader)
      @doc = @class.new
      @doc.image = stub_file('old.jpeg')
      @doc.save.should be_truthy
      File.exists?(public_path('uploads/old.jpeg')).should be_truthy
      File.exists?(public_path('uploads/thumb_old.jpeg')).should be_truthy
    end

    after do
      FileUtils.rm_rf(file_path("uploads"))
    end

    it "should remove old file if old file had a different path" do
      @doc.image = stub_file('new.jpeg')
      @doc.save.should be_truthy
      File.exists?(public_path('uploads/new.jpeg')).should be_truthy
      File.exists?(public_path('uploads/thumb_new.jpeg')).should be_truthy
      File.exists?(public_path('uploads/old.jpeg')).should be_falsey
      File.exists?(public_path('uploads/thumb_old.jpeg')).should be_falsey
    end

    it "should not remove file if old file had the same path" do
      @doc.image = stub_file('old.jpeg')
      @doc.save.should be_truthy
      File.exists?(public_path('uploads/old.jpeg')).should be_truthy
      File.exists?(public_path('uploads/thumb_old.jpeg')).should be_truthy
    end
  end

  describe '#mount_uploader removing old files with multiple uploaders' do

    before do
      @uploader = Class.new(MongoUploader)
      @class = reset_mongo_class(@uploader)
      @uploader1 = Class.new(CarrierWave::Uploader::Base)
      @class.mount_uploader(:textfile, @uploader1)
      @doc = @class.new
      @doc.image = stub_file('old.jpeg')
      @doc.textfile = stub_file('old.txt')
      @doc.save.should be_truthy
      File.exists?(public_path('uploads/old.jpeg')).should be_truthy
      File.exists?(public_path('uploads/old.txt')).should be_truthy
    end

    after do
      FileUtils.rm_rf(file_path("uploads"))
    end

    it "should remove old file1 and file2 if old file1 and file2 had a different paths" do
      @doc.image = stub_file('new.jpeg')
      @doc.textfile = stub_file('new.txt')
      @doc.save.should be_truthy
      File.exists?(public_path('uploads/new.jpeg')).should be_truthy
      File.exists?(public_path('uploads/old.jpeg')).should be_falsey
      File.exists?(public_path('uploads/new.txt')).should be_truthy
      File.exists?(public_path('uploads/old.txt')).should be_falsey
    end

    it "should remove old file1 but not file2 if old file1 had a different path but old file2 has the same path" do
      @doc.image = stub_file('new.jpeg')
      @doc.textfile = stub_file('old.txt')
      @doc.save.should be_truthy
      File.exists?(public_path('uploads/new.jpeg')).should be_truthy
      File.exists?(public_path('uploads/old.jpeg')).should be_falsey
      File.exists?(public_path('uploads/old.txt')).should be_truthy
    end

    it "should not remove file1 or file2 if file1 and file2 have the same paths" do
      @doc.image = stub_file('old.jpeg')
      @doc.textfile = stub_file('old.txt')
      @doc.save.should be_truthy
      File.exists?(public_path('uploads/old.jpeg')).should be_truthy
      File.exists?(public_path('uploads/old.txt')).should be_truthy
    end
  end

  describe '#mount_uploader removing old files with mount_on' do

    before do
      @class = reset_mongo_class
      @uploader1 = Class.new(CarrierWave::Uploader::Base)
      @class.mount_uploader(:avatar, @uploader1, :mount_on => :another_image)
      @doc = @class.new
      @doc.avatar = stub_file('old.jpeg')
      @doc.save.should be_truthy
      File.exists?(public_path('uploads/old.jpeg')).should be_truthy
    end

    after do
      FileUtils.rm_rf(file_path("uploads"))
    end

    it "should remove old file if old file had a different path" do
      @doc.avatar = stub_file('new.jpeg')
      @doc.save.should be_truthy
      File.exists?(public_path('uploads/new.jpeg')).should be_truthy
      File.exists?(public_path('uploads/old.jpeg')).should be_falsey
    end

    it "should not remove file if old file had the same path" do
      @doc.avatar = stub_file('old.jpeg')
      @doc.save.should be_truthy
      File.exists?(public_path('uploads/old.jpeg')).should be_truthy
    end
  end

  # Mongoid::Paranoia support is only part of Mongoid 3.x. It was removed from
  # Mongoid 4.x.
  if defined?(Mongoid::Paranoia)
    describe "with paranoia enabled" do
      before do
        @class = reset_mongo_class
        @class.collection.drop
        @class.class_eval do
          include Mongoid::Paranoia
        end

        @doc = @class.new(image: stub_file("old.jpeg"))
        @doc.save.should be_truthy
      end

      it "should not remove underlying image after #destroy" do
        @doc.destroy.should be_truthy
        @class.count.should eql(0)
        @class.deleted.count.should eql(1)
        File.exist?(public_path('uploads/old.jpeg')).should be_truthy
      end

      it "should remove underlying image after #destroy!" do
        @doc.destroy!.should be_truthy
        @class.count.should eql(0)
        @class.deleted.count.should eql(0)
        File.exist?(public_path('uploads/old.jpeg')).should be_falsey
      end
    end
  end

  context "JSON serialization with multiple uploaders" do
    before do
      @class = reset_mongo_class
      @class.send(:mount_uploader, :textfile,AnotherMongoUploader)
      @event = @class.new
      @event.image = stub_file('old.jpeg')
      @event.textfile = stub_file('old.txt')
    end

    it "serializes the correct values" do
      @event.serializable_hash["image"]["url"].should match(/old\.jpeg$/)
      @event.serializable_hash["textfile"]["url"].should match(/old\.txt$/)
    end

    it "should have JSON for each uploader" do
      parsed = JSON.parse(@event.to_json)
      parsed["image"]["url"].should match(/old\.jpeg$/)
      parsed["textfile"]["url"].should match(/old\.txt$/)
    end
  end

end
