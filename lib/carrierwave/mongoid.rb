# encoding: utf-8

require 'mongoid'
require 'mongoid-grid_fs'
require 'carrierwave'
require 'carrierwave/validations/active_model'

module CarrierWave
  module Mongoid
    include CarrierWave::Mount
    ##
    # See +CarrierWave::Mount#mount_uploader+ for documentation
    #
    def mount_uploader(column, uploader=nil, options={}, &block)
      field options[:mount_on] || column

      super

      alias_method :read_uploader, :read_attribute
      alias_method :write_uploader, :write_attribute
      public :read_uploader
      public :write_uploader

      include CarrierWave::Validations::ActiveModel

      validates_integrity_of  column if uploader_option(column.to_sym, :validate_integrity)
      validates_processing_of column if uploader_option(column.to_sym, :validate_processing)

      after_save :"store_#{column}!"
      before_save :"write_#{column}_identifier"
      after_destroy :"remove_#{column}!"
      if Gem::Version.new(CarrierWave::VERSION) >= Gem::Version.new("1.0.beta")
        before_update :"store_previous_changes_for_#{column}"
      else
        before_update :"store_previous_model_for_#{column}"
      end
      after_save :"remove_previously_stored_#{column}"

      class_eval <<-RUBY, __FILE__, __LINE__+1
        def #{column}=(new_file)
          column = _mounter(:#{column}).serialization_column

          # We're using _new_ and _old_ placeholder values to force Mongoid to
          # recognize changes in embedded documents. Before we assign these
          # values, we need to store the original file name in case we need to
          # delete it when document is saved.
          previous_uploader_value = read_uploader(column)
          @_previous_uploader_value_for_#{column} = previous_uploader_value

          # mongoid won't upload a new file if there was no file previously.
          write_uploader(column, '_old_') if self.persisted? && read_uploader(column).nil?

          send(:"\#{column}_will_change!")
          super
        end

        def remove_#{column}=(arg)
          if ['1', true].include?(arg)
            column = _mounter(:#{column}).serialization_column
            send(:"\#{column}_will_change!")
          end
          super
        end

        def remove_#{column}!
          super unless respond_to?(:paranoid?) && paranoid? && flagged_for_destroy?
        end

        # Overrides Mongoid's default dirty behavior to instead work more like
        # ActiveRecord's. Mongoid doesn't deem an attribute as changed unless
        # the new value is different than the original. Given that CarrierWave
        # caches files before save, it's necessary to know that there's a
        # pending change even though the attribute value itself might not
        # reflect that yet.
        def #{column}_changed?
          changed_attributes.has_key?("#{column}")
        end

        # The default Mongoid attribute_will_change! method is not enough
        # when we want to upload a new file in an existing embedded document.
        # The custom version of that method forces the callbacks to be
        # ran and so does the upload.
        def #{column}_will_change!
          changed_attributes["#{column}"] = '_new_'
        end

        # Since we had to use tricks with _old_ and _new_ values to properly
        # track changes in embedded documents, we need to overwrite this method
        # to remove the original file if it was replaced with a new one that
        # had a different name.
        if Gem::Version.new(CarrierWave::VERSION) >= Gem::Version.new("1.0.beta")
          def remove_previously_stored_#{column}
            before, after = @_previous_changes_for_#{column}
            # Don't delete if the files had the same name
            return if before.nil? && after.nil?
            # Proceed to remove the file, use the original name instead of '_new_'
            before = @_previous_uploader_value_for_#{column} || before
            _mounter(:#{column}).remove_previous([before], [after])
          end
        end

        # CarrierWave 1.1 references ::ActiveRecord constant directly which
        # will fail in projects without ActiveRecord. We need to overwrite this
        # method to avoid it.
        # See https://github.com/carrierwaveuploader/carrierwave/blob/07dc4d7bd7806ab4b963cf8acbad73d97cdfe74e/lib/carrierwave/mount.rb#L189
        def store_previous_changes_for_#{column}
          @_previous_changes_for_#{column} = changes[_mounter(:#{column}).serialization_column]
        end

        def find_previous_model_for_#{column}
          if self.embedded?
            if self.respond_to?(:__metadata) # Mongoid >= 4.0.0.beta1
              ancestors = [[ self.__metadata.key, self._parent ]].tap { |x| x.unshift([ x.first.last.__metadata.key, x.first.last._parent ]) while x.first.last.embedded? }
            else # Mongoid < 4.0.0.beta1
              ancestors = [[ self.metadata.key, self._parent ]].tap { |x| x.unshift([ x.first.last.metadata.key, x.first.last._parent ]) while x.first.last.embedded? }
            end
            first_parent = ancestors.first.last
            reloaded_parent = first_parent.class.unscoped.find(first_parent.to_key.first)
            association = ancestors.inject(reloaded_parent) { |parent,(key,ancestor)| (parent.is_a?(Array) ? parent.find(ancestor.to_key.first) : parent).send(key) }
            association.is_a?(Array) ? association.find(to_key.first) : association
          else
            self.class.unscoped.for_ids(to_key).first
          end
        end

        def serializable_hash(options=nil)
          hash = {}

          except = options && options[:except] && Array.wrap(options[:except]).map(&:to_s)
          only   = options && options[:only]   && Array.wrap(options[:only]).map(&:to_s)

          self.class.uploaders.each do |column, uploader|
            if (!only && !except) || (only && only.include?(column.to_s)) || (except && !except.include?(column.to_s))
              if Gem::Version.new(CarrierWave::VERSION) >= Gem::Version.new("1.0.beta")
                next if _mounter(column.to_sym).uploaders.blank?
                hash[column.to_s] = _mounter(column.to_sym).uploaders[0].serializable_hash
              else
                hash[column.to_s] = _mounter(column.to_sym).uploader.serializable_hash
              end
            end
          end
          super(options).merge(hash)
        end
      RUBY
    end

    if Gem::Version.new(CarrierWave::VERSION) >= Gem::Version.new('1.0.beta')
      def mount_uploaders(column, uploader = nil, options = {}, &block)
        field (options[:mount_on] || column), type: Array, default: []

        super

        alias_method :read_uploader, :read_attribute
        alias_method :write_uploader, :write_attribute
        public :read_uploader
        public :write_uploader

        include CarrierWave::Validations::ActiveModel

        validates_integrity_of column if uploader_option(column.to_sym, :validate_integrity)
        validates_processing_of column if uploader_option(column.to_sym, :validate_processing)

        before_update :"store_previous_changes_for_#{column}"
        before_save :"write_#{column}_identifier"
        after_save :"store_#{column}!"
        after_save :"remove_previously_stored_#{column}"
        after_destroy :"remove_#{column}!"

        class_eval <<-RUBY, __FILE__, (__LINE__ + 1)
          def #{column}=(new_files)
            column = _mounter(:#{column}).serialization_column
  
            previous_uploader_value = read_uploader(column)
            @_previous_uploader_value_for_#{column} = previous_uploader_value
  
            write_uploader(column, []) if self.persisted? && read_uploader(column).nil?
  
            send(:"\#{column}_will_change!")

            super
          end

          def #{column}_changed?
            changed_attributes.has_key?("#{column}")
          end

          def remove_#{column}=(value)
            if ['1', true].include?(value)
              column = _mounter(:#{column}).serialization_column

              send(:"\#{column}_will_change!")
            end

            super
          end

          # The default Mongoid attribute_will_change! method is not enough
          # when we want to upload a new file in an existing embedded document.
          # The custom version of that method forces the callbacks to be
          # ran and so does the upload.
          def #{column}_will_change!
            changed_attributes["#{column}"] = ['_new_']
          end

          def remove_previously_stored_#{column}
            before, after = @_previous_changes_for_#{column}
            # Don't delete if the files had the same name
            return if before.nil? && after.nil?
            # Proceed to remove the file, use the original name instead of '_new_'
            before = @_previous_uploader_value_for_#{column} || before
            _mounter(:#{column}).remove_previous(Array.wrap(before), Array.wrap(after))
          end

          def serializable_hash(options = nil)
            hash = {}
  
            except = options && options[:except] && Array.wrap(options[:except]).map(&:to_s)
            only = options && options[:only] && Array.wrap(options[:only]).map(&:to_s)
  
            self.class.uploaders.each do |column, _uploader|
              if (!only && !except) || (only && only.include?(column.to_s)) || (except && !except.include?(column.to_s))
                next if _mounter(column.to_sym).uploaders.blank?
                hash[column.to_s] = _mounter(column.to_sym).uploaders.map(&:serializable_hash)
              end
            end

            super(options).merge(hash)
          end

          def store_previous_changes_for_#{column}
            @_previous_changes_for_#{column} = changes[_mounter(:#{column}).serialization_column]
          end
        RUBY
      end
    end
  end # Mongoid
end # CarrierWave

CarrierWave::Storage.autoload :GridFS, 'carrierwave/storage/grid_fs'

class CarrierWave::Uploader::Base
  add_config :grid_fs_access_url

  configure do |config|
    config.storage_engines[:grid_fs] = "CarrierWave::Storage::GridFS"
  end
end

Mongoid::Document::ClassMethods.send(:include, CarrierWave::Mongoid)
