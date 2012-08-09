require 'rubygems'
require 'bundler/setup'
require 'rspec'
require 'tempfile'

require 'carrierwave'
require 'carrierwave/mongoid'

logger = Logger.new('log/test.log')
if CarrierWave::Mongoid.is_mongoid_3_x?
  Mongoid.load!(File.join(File.dirname(__FILE__), "config/mongoid_3_x_config.yml"), :test)
  Mongoid.logger = logger
  Moped.logger = logger
else
  Mongoid.configure do |config|
    config.logger = logger
    config.master = Mongo::Connection.new('localhost', 27017,
    :logger => logger).db('carrierwave_test')
  end
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
        f = File.open(file_path(filename))
        return f
      end

      def stub_tempfile(filename, mime_type=nil, fake_name=nil)
        raise "#{path} file does not exist" unless File.exist?(file_path(filename))

        t = Tempfile.new(filename)
        FileUtils.copy_file(file_path(filename), t.path)

        t.stub!(:local_path => "",
                :original_filename => filename || fake_name,
                :content_type => mime_type)

        return t
      end
    end

    module I18nHelpers
      def change_locale_and_store_translations(locale, translations, &block)
        current_locale = I18n.locale
        begin
          I18n.backend.store_translations locale, translations
          I18n.locale = locale
          yield
        ensure
          I18n.reload!
          I18n.locale = current_locale
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include CarrierWave::Test::MockFiles
  config.include CarrierWave::Test::I18nHelpers
end
