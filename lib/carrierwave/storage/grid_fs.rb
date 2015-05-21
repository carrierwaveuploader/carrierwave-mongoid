# encoding: utf-8

module CarrierWave
  module Storage

    ##
    # The GridFS store uses MongoDB's GridStore file storage system to store files
    #
    # When you already have a Mongo connection object (for example through Mongoid)
    # you can also reuse this connection:
    #
    #     CarrierWave.configure do |config|
    #       config.storage = :grid_fs
    #       config.grid_fs_access_url = "/system/uploads"
    #     end
    #
    #   In the above example your documents url will look like:
    #
    #      http://your-app.com/system/uploads/:document-identifier-here
    #
    class GridFS < Abstract

      class File
        attr_reader :path
        attr_reader :uploader
        attr_reader :grid_file

        def initialize(uploader, path)
          @path = path
          @uploader = uploader
          @grid_file = nil
        end

        def url
          unless @uploader.grid_fs_access_url
            nil
          else
            ::File.join(@uploader.grid_fs_access_url, path)
          end
        end

        def grid_file(&block)
          @grid_file ||= grid[path]
        end

        def write(file)
          grid[@uploader.store_path] = file
        ensure
          @grid_file = nil
        end

        def read
          grid_file.data if grid_file
        end

        %w( delete content_type length md5 ).each do |method|
          class_eval <<-__, __FILE__, __LINE__
            def #{ method }
              grid_file.#{ method } if grid_file
            end
          __
        end

        alias :content_length :length
        alias :file_length :length
        alias :size :length

      protected
        class << File
          attr_accessor :grid
        end

        self.grid = ::Mongoid::GridFS

        def grid
          self.class.grid
        end
      end # File

      ##
      # Store the file in MongoDB's GridFS GridStore
      #
      # === Parameters
      #
      # [file (CarrierWave::SanitizedFile)] the file to store
      #
      # === Returns
      #
      # [CarrierWave::SanitizedFile] a sanitized file
      #
      def store!(file)
        stored = CarrierWave::Storage::GridFS::File.new(uploader, uploader.store_path)
        stored.write(file)
        stored
      end

      ##
      # Retrieve the file from MongoDB's GridFS GridStore
      #
      # === Parameters
      #
      # [identifier (String)] the filename of the file
      #
      # === Returns
      #
      # [CarrierWave::Storage::GridFS::File] a sanitized file
      #
      def retrieve!(identifier)
        CarrierWave::Storage::GridFS::File.new(uploader, uploader.store_path(identifier))
      end

    end # GridFS
  end # Storage
end # CarrierWave
