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

        t.stub(:local_path => "",
               :original_filename => filename || fake_name,
               :content_type => mime_type)

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
end
