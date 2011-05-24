require 'rubygems'
require 'bundler/setup'
require 'rspec'

require 'carrierwave'
require 'carrierwave/mongoid'

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
    end
  end
end

RSpec.configure do |config|
  config.include CarrierWave::Test::MockFiles
end
