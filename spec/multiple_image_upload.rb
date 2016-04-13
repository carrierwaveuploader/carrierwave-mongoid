# encoding: utf-8
require 'spec_helper'
require 'carrierwave/mongoid'

def reset_mongo_class(uploader = MongoUploader)
  define_mongo_class('MongoUser') do
    include Mongoid::Document
    store_in :collection => 'users'
    field :folder, :default => ''
    mount_uploaders :images, uploader
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

  describe '#images' do

    context "when nothing is assigned" do

      before do
        mongo_user_klass = reset_mongo_class
        @document = mongo_user_klass.new
      end

      it "returns an empty array" do
        @document.images.should be_blank
      end

    end

    context "when an empty string is assigned" do

      before do
        mongo_user_klass = reset_mongo_class
        @document = mongo_user_klass.new(:images => [])
        @document.save
      end

      it "returns an empty array" do
        @saved_doc = MongoUser.first
        @saved_doc.images.should be_blank
      end

    end

  end

end