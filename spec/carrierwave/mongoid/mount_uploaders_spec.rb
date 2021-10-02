# frozen_string_literal: true

require 'spec_helper'

describe CarrierWave::Mongoid do
  if Gem::Version.new(CarrierWave::VERSION) >= Gem::Version.new('1.0.beta')
    describe '.mount_uploaders' do
      let(:uploader_class) do
        Class.new(CarrierWave::Uploader::Base)
      end

      let(:model_class) do
        uploader = uploader_class

        Class.new do
          include Mongoid::Document

          store_in collection: :token_models

          field :name
          mount_uploaders :images, uploader

          def self.model_name
            ActiveModel::Name.new(self, nil, 'TokenModel')
          end
        end
      end

      let!(:model) { model_class.new }
      let(:record) { model_class.first }

      after do
        model_class.collection.drop
      end

      describe 'model#destroy' do
        let(:identifiers) { ['portrait.jpg', 'test.jpeg'] }
        let(:files) { identifiers.map { |i| stub_file(i) } }
        let(:current_paths) { identifiers.map { |i| public_path("uploads/#{i}") } }
        let(:current_pathnames) { current_paths.map { |p| Pathname.new(p) } }

        describe 'when file assigned' do
          it 'removes the file from the filesystem' do
            model.images = files
            expect(model.save).to be_truthy

            expect(model.images.count).to eq files.count
            expect(model.images).to all(be_an_instance_of(uploader_class))
            expect(model.images.map(&:current_path)).to match_array(current_paths)
            expect(current_pathnames).to all(be_file)

            model.destroy!

            expect(current_pathnames.map(&:exist?)).to all(be_falsey)
          end
        end

        describe 'when file is not assigned' do
          before do
            model.save!
          end

          it 'deletes the instance of model_class after save' do
            expect { model.destroy }.to change(model_class, :count).from(1).to(0)
          end

          it 'deletes the instance of model_class after save and then re-looking up the instance' do
            expect { record.destroy }.to change(model_class, :count).from(1).to(0)
          end
        end
      end

      describe 'model#save' do
        let(:identifiers) { ['portrait.jpg', 'test.jpeg'] }
        let(:files) { identifiers.map { |i| stub_file(i) } }
        let(:current_paths) { identifiers.map { |i| public_path("uploads/#{i}") } }

        it 'after it was initialized with params' do
          model = model_class.new(images: files)

          expect(model.save).to be_truthy
          expect(model.images.count).to eq files.count
          expect(model.images).to all(be_an_instance_of(uploader_class))
          expect(model.images.map(&:current_path)).to match_array(current_paths)
        end

        context 'when no file is assigned' do
          it 'image is blank' do
            expect(model.save).to be_truthy
            expect(model.images).to be_blank
          end
        end

        context 'when a file is assigned' do
          it 'copies the file to the upload directory' do
            model.images = files

            expect(model.save).to be_truthy
            expect(model.images.count).to eq files.count
            expect(model.images).to all(be_an_instance_of(uploader_class))
            expect(model.images.map(&:current_path)).to match_array(current_paths)
          end

          it 'saves the filename in the database' do
            model.images = files

            expect(model.save).to be_truthy
            expect(model[:images]).to match_array(identifiers)
            expect(model.images_identifiers).to match_array(identifiers)
          end

          context 'when remove_images? is true' do
            it 'removes the image' do
              model.images = stub_file('test.jpeg')
              model.save
              model.remove_images = true
              expect(model.save).to be_truthy
              model.reload
              expect(model.images).to be_blank
              expect(model.images_identifiers).to be_blank
            end
          end

          it 'marks images as changed when saving a new image' do
            model.save
            expect(model.images_changed?).to be false

            model.images = files
            expect(model.images_changed?).to be true

            model.save
            model.reload
            expect(model.images_changed?).to be false

            model.images = files
            expect(model.images_changed?).to be true
          end
        end
      end

      describe 'model#remove_uploaders=' do
        before do
          model.save
        end

        it 'treats true argument such that attribute is marked as changed' do
          model.remove_images = true

          expect(model.images_changed?).to be true
        end

        it "treats '1' argument such that attribute is marked as changed" do
          model.remove_images = '1'

          expect(model.images_changed?).to be true
        end

        it 'treats false argument such that attribute is not marked as changed' do
          model.remove_images = false

          expect(model.images_changed?).to be false
        end

        it 'treats nil argument such that attribute is not marked as changed' do
          model.remove_images = nil

          expect(model.images_changed?).to be false
        end

        it "treats '0' argument such that attribute is not marked as changed" do
          model.remove_images = '0'

          expect(model.images_changed?).to be false
        end
      end

      describe 'model#uploaders' do
        context 'when nothing was assigned yet' do
          it 'returns an empty array' do
            expect(model.images).to match_array([])
          end
        end

        context 'when assigning an empty array' do
          before do
            model.images = []
          end

          it 'returns an empty array' do
            expect(model.images).to match_array([])
          end

          context 'when saving and reloading' do
            before do
              model.save
              model.reload
            end

            it 'returns an empty array' do
              expect(model.images).to match_array([])
            end
          end
        end

        context 'when assigning values' do
          context 'without using the model, i.e. writing filenames directly to the database record' do
            let(:identifiers) { ['test1.jpg', 'test2.jpg'] }

            before do
              model.save!
              model.collection.update_one({ _id: model.id }, { images: identifiers })
            end

            it 'returns an array of uploaders' do
              expect(model_class.first.images).to all(be_an_instance_of(uploader_class))
            end

            describe 'the returned uploaders' do
              it 'have the matching identifiers', if: Gem::Version.new(CarrierWave::VERSION) >= Gem::Version.new('2') do
                expect(model_class.first.images.map(&:identifier)).to match_array(identifiers)
              end

              it 'have their paths set to the store directory' do
                expect(model_class.first.images.map(&:current_path)).to match_array(identifiers.map { |i| public_path("uploads/#{i}") })
              end
            end
          end

          context 'when using the methods on the model' do
            context 'when there are no uploaders assigned yet' do
              let(:identifiers) { ['test.jpeg'] }

              before do
                model.images = identifiers.map { |f| stub_file(f) }
              end

              it 'caches a file' do
                expect(model.images).to all(be_an_instance_of(uploader_class))
                expect(model.images.map(&:identifier)).to match_array(identifiers)
              end

              it 'does not write anything to the database, in order to prevent overridden filenames to fail because of unassigned attributes' do
                expect(model[:images]).to match_array([])
              end

              it 'copies a file into into the cache directory' do
                expect(model.images.first.current_path).to match(/^#{Regexp.escape(public_path('uploads/tmp'))}/)
              end
            end

            context 'when there are already uploaders assigned' do
              let!(:model) { model_class.create(images: [stub_file('portrait.jpg')]) }

              before do
                model.images = model.images.push(stub_file('test.jpeg'))
              end

              it 'caches the file' do
                expect(model.images).to all(be_an_instance_of(uploader_class))
                expect(model.images.map(&:identifier)).to match_array(['portrait.jpg', 'test.jpeg'])
              end

              it 'does not write anything to the database, in order to prevent overridden filenames to fail because of unassigned attributes' do
                expect(model[:images]).to match_array(['portrait.jpg'])
              end

              it 'copies a file into into the cache directory' do
                expect(model.images.map(&:current_path)).to all(match(/^#{Regexp.escape(public_path('uploads/tmp'))}/))
              end
            end
          end
        end
      end

      describe 'model#uploaders=' do
        context 'when nil is assigned' do
          it 'does not set the value' do
            model.images = nil

            expect(model.images).to be_blank
          end
        end

        context 'when an empty string is assigned' do
          it 'does not set the value' do
            model.images = ''

            expect(model.images).to be_blank
          end
        end

        context 'when assigning files' do
          let(:files) { [stub_file('portrait.jpg'), stub_file('test.jpeg')] }

          before do
            model.images = files
          end

          it 'caches the files' do
            expect(model.images.count).to be files.count
            expect(model.images).to all(be_an_instance_of(uploader_class))
          end

          it 'does not write to the database' do
            expect(model[:images]).to be_empty
          end

          it 'copies a file into into the cache directory' do
            expect(model.images.map(&:current_path)).to all(start_with(public_path('uploads/tmp')))
          end
        end

        context 'when validating integrity' do
          let(:uploader_class) do
            Class.new(CarrierWave::Uploader::Base) do
              process :munge

              def munge
                raise CarrierWave::IntegrityError
              end
            end
          end

          let(:files) { [stub_file('portrait.jpg')] }

          before do
            model.images = files
          end

          it 'makes the document invalid when an integrity error occurs' do
            expect(model).to be_invalid
          end

          it 'uses I18n for integrity error messages' do
            translations = { mongoid: { errors: { messages: { carrierwave_integrity_error: 'is not of an allowed file type' } } } }
            change_locale_and_store_translations(:en, translations) do
              model.valid?

              expect(model.errors[:images]).to eq ['is not of an allowed file type']
            end

            translations = { mongoid: { errors: { messages: { carrierwave_integrity_error: 'tipo de imagem não permitido.' } } } }
            change_locale_and_store_translations(:pt, translations) do
              model.valid?

              expect(model.errors[:images]).to eq ['tipo de imagem não permitido.']
            end
          end
        end

        context 'when validating processing' do
          let(:uploader_class) do
            Class.new(CarrierWave::Uploader::Base) do
              process :munge

              def munge
                raise CarrierWave::ProcessingError
              end
            end
          end

          let(:files) { [stub_file('portrait.jpg')] }

          before do
            model.images = files
          end

          it 'makes the document invalid when a processing error occurs' do
            expect(model).not_to be_valid
          end

          it 'uses I18n for processing error messages' do
            translations = { mongoid: { errors: { messages: { carrierwave_processing_error: 'failed to be processed' } } } }
            change_locale_and_store_translations(:en, translations) do
              model.valid?
              expect(model.errors[:images]).to eq ['failed to be processed']
            end

            translations = { mongoid: { errors: { messages: { carrierwave_processing_error: 'falha ao processar imagem.' } } } }
            change_locale_and_store_translations(:pt, translations) do
              model.valid?
              expect(model.errors[:images]).to eq ['falha ao processar imagem.']
            end
          end
        end
      end

      describe 'model#update' do
        let(:identifiers) { ['portrait.jpg', 'test.jpeg'] }
        let(:files) { identifiers.map { |i| stub_file(i) } }
        let(:current_paths) { identifiers.map { |i| public_path("uploads/#{i}") } }
        let(:current_pathnames) { current_paths.map { |p| Pathname.new(p) } }

        before do
          model_class.create!(images: files)
        end

        it 'replaced it by a file with the same name' do
          record.update!(images: [stub_file('test.jpeg')])

          record.reload

          expect(record[:images]).to match_array(['test.jpeg'])
          expect(record.images_identifiers).to match_array(['test.jpeg'])
        end
      end

      describe 'model#to_json' do
        let(:json) { JSON.parse(record.to_json) }

        context 'when assigning values' do
          context 'without using the model, i.e. writing filenames directly to the database record' do
            before do
              model[:images] = identifiers
              model.save!
            end

            context 'when the identifiers are blank' do
              let(:identifiers) { nil }

              it 'returns valid JSON' do
                expect(json['images']).to match_array([])
              end
            end

            context 'when the identifiers are present' do
              let(:identifiers) { ['portrait.jpg', 'test.jpeg'] }

              it 'returns valid JSON' do
                expected = identifiers.map do |i|
                  { 'url' => "/uploads/#{i}" }
                end

                expect(json['images']).to match_array(expected)
              end

              it 'returns valid JSON when called on a collection containing uploaders from the model' do
                plaintext = { data: record.images }.to_json

                expected = identifiers.map do |i|
                  { 'url' => "/uploads/#{i}" }
                end

                expect(JSON.parse(plaintext)).to eq('data' => expected)
              end

              it 'returns valid JSON when using :only' do
                plaintext = record.to_json(only: [:_id])

                expect(JSON.parse(plaintext)).to eq('_id' => record.id.as_json)
              end

              it 'returns valid JSON when using :except' do
                plaintext = record.to_json(except: %i[_id images])

                expect(JSON.parse(plaintext)).to eq('name' => nil)
              end
            end
          end
        end
      end

      describe 'removing old files' do
        let(:identifiers) { ['old.jpeg'] }
        let(:files) { identifiers.map { |i| stub_file(i) } }
        let(:current_paths) { identifiers.map { |i| public_path("uploads/#{i}") } }
        let(:current_pathnames) { current_paths.map { |p| Pathname.new(p) } }

        let!(:model) { model_class.create!(images: files) }

        after do
          FileUtils.rm_rf(public_path('uploads'))
        end

        describe 'before removing' do
          it 'all files exist' do
            expect(current_pathnames).to all(be_file)
          end
        end

        describe 'normally' do
          it 'removes old file if old file had a different path' do
            model.images = [stub_file('new.jpeg')]
            expect(model.save).to be_truthy
            expect(File).to exist(public_path('uploads/new.jpeg'))
            expect(File).not_to exist(public_path('uploads/old.jpeg'))
          end

          it 'does not remove old file if old file had a different path but config is false' do
            uploader_class.remove_previously_stored_files_after_update = false
            model.images = [stub_file('new.jpeg')]
            expect(model.save).to be_truthy
            expect(File).to exist(public_path('uploads/new.jpeg'))
            expect(File).to exist(public_path('uploads/old.jpeg'))
          end

          it 'does not remove file if old file had the same path' do
            model.images = [stub_file('old.jpeg')]
            expect(model.save).to be_truthy
            expect(File).to exist(public_path('uploads/old.jpeg'))
          end

          it 'does not remove file if validations fail on save' do
            model_class.validate { |r| r.errors.add :textfile, 'FAIL!' }
            model.images = [stub_file('new.jpeg')]
            expect(model.save).to be_falsey
            expect(File).to exist(public_path('uploads/old.jpeg'))
          end
        end

        describe 'with an overridden filename' do
          let(:uploader_class) do
            Class.new(CarrierWave::Uploader::Base) do
              def filename
                model.name + File.extname(super)
              end
            end
          end

          let!(:model) { model_class.create!(name: 'Mike', images: [stub_file('old.jpeg')]) }

          it 'does not remove file if old file had the same dynamic path' do
            expect(File).to exist(public_path('uploads/Mike.jpeg'))
            expect(model.images.first.read).to eq 'this is stuff'

            model.update!(images: [stub_file('test.jpeg')])

            expect(File).to exist(public_path('uploads/Mike.jpeg'))
          end

          it 'removes old file if old file had a different dynamic path' do
            expect(File).to exist(public_path('uploads/Mike.jpeg'))
            expect(model.images.first.read).to eq 'this is stuff'

            model.update!(name: 'Frank', images: [stub_file('test.jpeg')])

            expect(File).to exist(public_path('uploads/Frank.jpeg'))
            expect(File).not_to exist(public_path('uploads/test.jpeg'))
          end
        end

        shared_examples 'embedded documents' do
          it 'removes old file if old file had a different path' do
            embedded_model.images = [stub_file('new.jpeg')]
            expect(embedded_model.save).to be_truthy
            expect(File).to exist(public_path('uploads/new.jpeg'))
            expect(File).not_to exist(public_path('uploads/old.jpeg'))
          end

          it 'does not remove old file if old file had a different path but config is false' do
            uploader_class.remove_previously_stored_files_after_update = false
            embedded_model.images = [stub_file('new.jpeg')]
            expect(embedded_model.save).to be_truthy
            expect(File).to exist(public_path('uploads/new.jpeg'))
            expect(File).to exist(public_path('uploads/old.jpeg'))
          end

          it 'does not remove file if old file had the same path' do
            embedded_model.images = [stub_file('old.jpeg')]
            expect(embedded_model.save).to be_truthy
            expect(File).to exist(public_path('uploads/old.jpeg'))
          end

          it 'does not remove file if validations fail on save' do
            embedded_model.class.validate { |r| r.errors.add :textfile, 'FAIL!' }
            embedded_model.images = [stub_file('new.jpeg')]
            expect(embedded_model.save).to be_falsey
            expect(File).to exist(public_path('uploads/old.jpeg'))
          end

          it "does not touch parent's dirty attributes" do
            model.name = 'Kirk'
            embedded_model.images = [stub_file('new.jpeg')]
            embedded_model.save!

            expect(embedded_model.save).to be_truthy
            expect(model.name).to eq 'Kirk'
          end
        end

        shared_examples 'double embedded documents' do
          it 'removes old file if old file had a different path' do
            double_embedded_model.images = [stub_file('new.jpeg')]
            expect(double_embedded_model.save).to be_truthy
            expect(File).to exist(public_path('uploads/new.jpeg'))
            expect(File).not_to exist(public_path('uploads/old.jpeg'))
          end

          it 'does not remove old file if old file had a different path but config is false' do
            uploader_class.remove_previously_stored_files_after_update = false
            double_embedded_model.images = [stub_file('new.jpeg')]
            expect(double_embedded_model.save).to be_truthy
            expect(File).to exist(public_path('uploads/new.jpeg'))
            expect(File).to exist(public_path('uploads/old.jpeg'))
          end

          it 'does not remove file if old file had the same path' do
            double_embedded_model.images = [stub_file('old.jpeg')]
            expect(double_embedded_model.save).to be_truthy
            expect(File).to exist(public_path('uploads/old.jpeg'))
          end

          it 'does not remove file if validations fail on save' do
            double_embedded_model_class.validate { |r| r.errors.add :textfile, 'FAIL!' }
            double_embedded_model.images = [stub_file('new.jpeg')]
            expect(double_embedded_model.save).to be_falsey
            expect(File).to exist(public_path('uploads/old.jpeg'))
          end
        end

        describe 'with document embedded as embeds_one' do
          let!(:model_class) do
            define_mongo_class('TokenModel') do
              include Mongoid::Document

              store_in collection: :token_models

              field :name

              embeds_one :token_embedded_model
            end
          end

          let!(:embedded_model_class) do
            uploader = uploader_class

            define_mongo_class('TokenEmbeddedModel') do
              include Mongoid::Document

              embedded_in :token_model

              field :title
              mount_uploaders :images, uploader
            end
          end

          let(:model) { model_class.new }
          let!(:embedded_model) { model.create_token_embedded_model(images: [stub_file('old.jpeg')]) }

          include_examples 'embedded documents'
        end

        describe 'with document embedded as embeds_one and parent document not matched the default scope' do
          let!(:model_class) do
            define_mongo_class('TokenModel') do
              include Mongoid::Document

              store_in collection: :token_models

              field :name

              embeds_one :token_embedded_model

              default_scope -> { where(always_false: false) }
            end
          end

          let!(:embedded_model_class) do
            uploader = uploader_class

            define_mongo_class('TokenEmbeddedModel') do
              include Mongoid::Document

              embedded_in :token_model

              field :title
              mount_uploaders :images, uploader
            end
          end

          let(:model) { model_class.new }
          let!(:embedded_model) { model.create_token_embedded_model(images: [stub_file('old.jpeg')]) }

          include_examples 'embedded documents'
        end

        describe 'with embedded documents' do
          let(:model_class) do
            embedded_model_class # Invoke class definition

            define_mongo_class('TokenModel') do
              include Mongoid::Document

              store_in collection: :token_models

              field :name

              embeds_many :token_embedded_models, cascade_callbacks: true
              accepts_nested_attributes_for :token_embedded_models
            end
          end

          let(:embedded_model_class) do
            double_embedded_model_class # Invoke class definition
            uploader = uploader_class

            define_mongo_class('TokenEmbeddedModel') do
              include Mongoid::Document

              embedded_in :token_model
              embeds_many :token_double_embedded_models

              field :title
              mount_uploaders :images, uploader
            end
          end

          let(:double_embedded_model_class) do
            uploader = uploader_class

            define_mongo_class('TokenDoubleEmbeddedModel') do
              include Mongoid::Document

              embedded_in :token_embedded_model

              mount_uploaders :images, uploader
            end
          end

          let(:model) { model_class.create! }
          let!(:embedded_model) { model.token_embedded_models.create!(images: [stub_file('old.jpeg')]) }

          include_examples 'embedded documents'

          it 'attaches a new file to an existing document that had no file at first' do
            model.save!
            model.reload

            model.token_embedded_models.first.update!(images: [stub_file('test.jpeg')])
            model.reload

            expect(model.token_embedded_models.first[:images]).to match_array ['test.jpeg']
          end

          it 'changes the file' do
            model.update_attributes token_embedded_models_attributes: { '0' => { _id: embedded_model._id, images: [stub_file('test.jpeg')] } }
            model.reload
            expect(model.token_embedded_models.first[:images]).to eq ['test.jpeg']
          end

          it 'removes a file' do
            model.update_attributes token_embedded_models_attributes: { '0' => { _id: embedded_model._id, remove_images: '1' } }
            model.reload
            expect(model.token_embedded_models.first[:images]).not_to be_present
          end

          describe 'with double embedded documents' do
            let!(:double_embedded_model) { embedded_model.token_double_embedded_models.create!(images: [stub_file('old.jpeg')]) }

            include_examples 'double embedded documents'
          end
        end

        describe 'with embedded documents and parent document not matched the default scope' do
          let(:model_class) do
            embedded_model_class # Invoke class definition

            define_mongo_class('TokenModel') do
              include Mongoid::Document

              store_in collection: :token_models

              field :name

              embeds_many :token_embedded_models

              default_scope -> { where(always_false: false) }
            end
          end

          let(:embedded_model_class) do
            double_embedded_model_class # Invoke class definition
            uploader = uploader_class

            define_mongo_class('TokenEmbeddedModel') do
              include Mongoid::Document

              embedded_in :token_model
              embeds_many :token_double_embedded_models

              field :title
              mount_uploaders :images, uploader
            end
          end

          let(:double_embedded_model_class) do
            uploader = uploader_class

            define_mongo_class('TokenDoubleEmbeddedModel') do
              include Mongoid::Document

              embedded_in :token_embedded_model

              mount_uploaders :images, uploader
            end
          end

          let(:model) { model_class.create! }
          let!(:embedded_model) { model.token_embedded_models.create!(images: [stub_file('old.jpeg')]) }

          include_examples 'embedded documents'

          describe 'with double embedded documents' do
            let!(:double_embedded_model) { embedded_model.token_double_embedded_models.create!(images: [stub_file('old.jpeg')]) }

            include_examples 'double embedded documents'
          end
        end

        describe 'with embedded documents and nested attributes' do
          let(:model_class) do
            embedded_model_class # Invoke class definition

            define_mongo_class('TokenModel') do
              include Mongoid::Document

              store_in collection: :token_models

              field :name

              embeds_many :token_embedded_models, cascade_callbacks: true
              accepts_nested_attributes_for :token_embedded_models
            end
          end

          let(:embedded_model_class) do
            uploader = uploader_class

            define_mongo_class('TokenEmbeddedModel') do
              include Mongoid::Document

              embedded_in :token_model

              field :title
              mount_uploaders :images, uploader
            end
          end

          let(:model) { model_class.create! }
          let!(:embedded_model) { model.token_embedded_models.create!(images: [stub_file('old.jpeg')]) }

          it 'sets the image on a save' do
            model.reload
            expect(model.token_embedded_models.first.images.first.path).to match(/old\.jpeg$/)
            expect(embedded_model.images.first.path).to match(/old\.jpeg$/)
          end

          it 'updates the image on update_attributes' do
            expect(model.update_attributes(token_embedded_models_attributes: [{ id: embedded_model.id, images: [stub_file('new.jpeg')] }])).to be_truthy
            model.reload
            expect(model.token_embedded_models.first.images.first.path).to match(/new\.jpeg$/)
            expect(embedded_model.reload.images.first.path).to match(/new\.jpeg$/)
          end
        end

        context 'with versions' do
          let(:uploader_class) do
            Class.new(CarrierWave::Uploader::Base) do
              version :thumb
            end
          end

          let!(:model) { model_class.create!(images: [stub_file('old.jpeg')]) }

          after do
            FileUtils.rm_rf(file_path('uploads'))
          end

          it 'removes old file if old file had a different path' do
            expect(File).to exist(public_path('uploads/old.jpeg'))
            expect(File).to exist(public_path('uploads/thumb_old.jpeg'))

            model.update!(images: [stub_file('new.jpeg')])

            expect(File).to exist(public_path('uploads/new.jpeg'))
            expect(File).to exist(public_path('uploads/thumb_new.jpeg'))
            expect(File).not_to exist(public_path('uploads/old.jpeg'))
            expect(File).not_to exist(public_path('uploads/thumb_old.jpeg'))
          end

          it 'does not remove file if old file had the same path' do
            expect(File).to exist(public_path('uploads/old.jpeg'))
            expect(File).to exist(public_path('uploads/thumb_old.jpeg'))

            model.update!(images: [stub_file('old.jpeg')])

            expect(File).to exist(public_path('uploads/old.jpeg'))
            expect(File).to exist(public_path('uploads/thumb_old.jpeg'))
          end
        end

        context 'with multiple uploaders' do
          let(:model_class) do
            uploader = uploader_class

            Class.new(CarrierWave::Uploader::Base) do
              include Mongoid::Document

              store_in collection: :token_models

              field :name
              mount_uploaders :images, uploader
              mount_uploaders :textfiles, uploader

              def self.model_name
                ActiveModel::Name.new(self, nil, 'TokenModel')
              end
            end
          end

          let!(:model) { model_class.create!(images: [stub_file('old.jpeg')], textfiles: [stub_file('old.txt')]) }

          after do
            FileUtils.rm_rf(file_path('uploads'))
          end

          it 'removes old file1 and file2 if old file1 and file2 had a different paths' do
            expect(File).to exist(public_path('uploads/old.jpeg'))
            expect(File).to exist(public_path('uploads/old.txt'))

            model.update!(images: [stub_file('new.jpeg')], textfiles: [stub_file('new.txt')])

            expect(File).to exist(public_path('uploads/new.jpeg'))
            expect(File).not_to exist(public_path('uploads/old.jpeg'))
            expect(File).to exist(public_path('uploads/new.txt'))
            expect(File).not_to exist(public_path('uploads/old.txt'))
          end

          it 'removes old file1 but not file2 if old file1 had a different path but old file2 has the same path' do
            expect(File).to exist(public_path('uploads/old.jpeg'))
            expect(File).to exist(public_path('uploads/old.txt'))

            model.update!(images: [stub_file('new.jpeg')], textfiles: [stub_file('old.txt')])

            expect(File).to exist(public_path('uploads/new.jpeg'))
            expect(File).not_to exist(public_path('uploads/old.jpeg'))
            expect(File).to exist(public_path('uploads/old.txt'))
          end

          it 'does not remove file1 or file2 if file1 and file2 have the same paths' do
            expect(File).to exist(public_path('uploads/old.jpeg'))
            expect(File).to exist(public_path('uploads/old.txt'))

            model.update!(images: [stub_file('old.jpeg')], textfiles: [stub_file('old.txt')])

            expect(File).to exist(public_path('uploads/old.jpeg'))
            expect(File).to exist(public_path('uploads/old.txt'))
          end
        end

        describe 'with mount_on' do
          let(:model_class) do
            uploader = uploader_class

            Class.new do
              include Mongoid::Document

              store_in collection: :token_models

              field :name
              mount_uploaders :avatars, uploader, mount_on: :images

              def self.model_name
                ActiveModel::Name.new(self, nil, 'TokenModel')
              end
            end
          end

          let!(:model) { model_class.create!(avatars: [stub_file('old.jpeg')]) }

          after do
            FileUtils.rm_rf(file_path('uploads'))
          end

          it 'removes old file if old file had a different path' do
            expect(File).to exist(public_path('uploads/old.jpeg'))

            model.update!(avatars: [stub_file('new.jpeg')])

            expect(File).to exist(public_path('uploads/new.jpeg'))
            expect(File).not_to exist(public_path('uploads/old.jpeg'))
          end

          it 'does not remove file if old file had the same path' do
            expect(File).to exist(public_path('uploads/old.jpeg'))

            model.update!(avatars: [stub_file('old.jpeg')])

            expect(File).to exist(public_path('uploads/old.jpeg'))
          end
        end
      end

      # Mongoid::Paranoia support is only part of Mongoid 3.x.
      # It was removed from Mongoid 4.x.
      if defined?(Mongoid::Paranoia)
        describe 'with paranoia enabled' do
          let(:model_class) do
            uploader = uploader_class

            Class.new do
              include Mongoid::Document
              include Mongoid::Paranoia

              store_in collection: :token_models

              field :name
              mount_uploaders :images, uploader

              def self.model_name
                ActiveModel::Name.new(self, nil, 'TokenModel')
              end
            end
          end

          let!(:model) { model_class.create!(images: [stub_file('old.jpeg')]) }

          it 'does not remove underlying image after #destroy' do
            expect(model.destroy).to be_truthy

            expect(model_class.count).to be(0)
            expect(model_class.deleted.count).to be(1)
            expect(File).to exist(public_path('uploads/old.jpeg'))
          end

          it 'removes underlying image after #destroy!' do
            expect(model.destroy!).to be_truthy

            expect(model_class.count).to be(0)
            expect(model_class.deleted.count).to be(0)
            expect(File).not_to exist(public_path('uploads/old.jpeg'))
          end
        end
      end
    end
  end
end
