require 'rubygems'
require 'bundler/setup'
require 'rspec'
require 'tempfile'
require 'stringio'

require 'carrierwave'
require 'carrierwave/mongoid'

Mongoid.configure do |config|
  config.connect_to('carrierwave_test')
end

if defined? Mongo
  Mongo::Logger.level = ::Logger::INFO
end

def file_path( *paths )
  File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', *paths))
end

def public_path( *paths )
  File.expand_path(File.join(File.dirname(__FILE__), 'public', *paths))
end

CarrierWave.root = public_path

module CarrierWave
  module Test
    module MockFiles
      def stub_file(filename, mime_type=nil, fake_name=nil)
        File.open(file_path(filename))
      end

      def stub_tempfile(filename, mime_type=nil, fake_name=nil)
        raise "#{path} file does not exist" unless File.exist?(file_path(filename))

        t = Tempfile.new(filename)
        FileUtils.copy_file(file_path(filename), t.path)

        allow(t).to receive(:local_path).and_return("")
        allow(t).to receive(:original_filename).and_return(filename || fake_name)
        allow(t).to receive(:content_type).and_return(mime_type)

        return t
      end
    end

    module I18nHelpers
      I18n.enforce_available_locales = false if I18n.respond_to? :enforce_available_locales=

      def change_locale_and_store_translations(locale, translations, &block)
        current_locale = I18n.locale
        current_enforce = I18n.config.enforce_available_locales
        begin
          I18n.config.enforce_available_locales = false
          I18n.backend.store_translations locale, translations
          I18n.locale = locale
          yield
        ensure
          I18n.reload!
          I18n.locale = current_locale
          I18n.config.enforce_available_locales = current_enforce
        end
      end
    end
  end
end

class SIO < StringIO
  attr_accessor :filename

  def initialize(filename, *args, &block)
    @filename = filename
    super(*args, &block)
  end
end

RSpec.configure do |config|
  config.include CarrierWave::Test::MockFiles
  config.include CarrierWave::Test::I18nHelpers
  config.color = true
end

def define_mongo_class(class_name, &block)
  Object.send(:remove_const, class_name) rescue nil
  klass = Object.const_set(class_name, Class.new)
  klass.class_eval(&block)
  klass
end
