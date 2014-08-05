# CarrierWave for Mongoid

This gem adds support for Mongoid and MongoDB's GridFS to
[CarrierWave](https://github.com/carrierwaveuploader/carrierwave/)

This functionality used to be part of CarrierWave but has since been extracted
into this gem.

[![Gem Version](http://img.shields.io/gem/v/carrierwave-mongoid.svg)](https://rubygems.org/gems/carrierwave-mongoid) [![Build Status](https://travis-ci.org/carrierwaveuploader/carrierwave-mongoid.svg)](http://travis-ci.org/carrierwaveuploader/carrierwave-mongoid) [![Code Climate](http://img.shields.io/codeclimate/github/carrierwaveuploader/carrierwave-mongoid.svg)](https://codeclimate.com/github/carrierwaveuploader/carrierwave-mongoid)

## Installation

Install the latest release:

    gem install carrierwave-mongoid

Require it in your code:

```ruby
require 'carrierwave/mongoid'
```

Or, in Rails you can add it to your Gemfile:

```ruby
gem 'carrierwave-mongoid', :require => 'carrierwave/mongoid'
```

Note: If using Rails 4, you'll need to make sure `mongoid-grid_fs` is `>= 1.9.0`.
If in doubt, run `bundle update mongoid-grid_fs`

```ruby
gem 'mongoid-grid_fs', github: 'ahoward/mongoid-grid_fs'
```

## Getting Started

Follow the "Getting Started" directions in the main
[Carrierwave repository](https://github.com/carrierwaveuploader/carrierwave/).

[Suggested] Add the field to your attr_accessor list for mass assignment
protection:

```ruby
attr_accessible :avatar, :avatar_cache
```

Now you can cache files by assigning them to the attribute; they will
automatically be stored when the record is saved. Ex:

```ruby
u = User.new
u.avatar = File.open('somewhere')
u.save!
```

## Using MongoDB's GridFS store

In your uploader, set the storage to `:grid_fs`:

```ruby
class AvatarUploader < CarrierWave::Uploader::Base
  storage :grid_fs
end
```

Bringing it all together, you can also configure Carrierwave to use Mongoid's
database connection and default all storage to GridFS. That might look something
like this:

```ruby
CarrierWave.configure do |config|
  config.storage = :grid_fs
  config.root = Rails.root.join('tmp')
  config.cache_dir = "uploads"
end
```

## Serving uploading files

Since GridFS doesn't make the files available via HTTP, you'll need to stream
them yourself. For example, in Rails, you could use the `send_data` method:

```ruby
class UsersController < ApplicationController
  def avatar
    content = @user.avatar.read
    if stale?(etag: content, last_modified: @user.updated_at.utc, public: true)
      send_data content, type: @user.avatar.file.content_type, disposition: "inline"
      expires_in 0, public: true
    end
  end
end

# and in routes.rb
resources :users do
  get :avatar, on: :member
end
```

You can optionally tell CarrierWave the URL you will serve your images from,
allowing it to generate the correct URL, by setting `grid_fs_access_url`:

```ruby
CarrierWave.configure do |config|
  config.grid_fs_access_url = "/systems/uploads"
end
```

## Route configuration

If you follow the instruction to this point, the uploaded images will be
stored to GridFS, and you are responsible for serving the images a public
endpoint. If you would like to use the `#url` method on the uploaded file, you
will need to take some additional steps.

The `grid_fs_access_url` configuration option is the prefix for the path of
the stored file in carrierwave.

Let's assume that we have a mounted `avatar` uploader on a `User` model and a
`GridfsController`. Let's also assume that your uploader definition
(i.e. `app/uploaders/avatar_uploader.rb`) defines `store_dir` like this:

```ruby
def store_dir
  "#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
end
```

If `grid_fs_access_url` (in `config/initializers/carrierwave.rb`) were:

```ruby
config.grid_fs_access_url = '/uploads/grid'
```

You would need to define a route in your `config/routes.rb` like so:

```ruby
match '/uploads/grid/user/avatar/:id/:filename' => 'gridfs#avatar'
```

Now, `user.avatar.url` should return an appropriate url path to use in your
views.

### Different uploaded versions

If you need to include different versions (e.g. thumbnails), additional routes
will help:

```ruby
match '/uploads/grid/user/avatar/:id/:filename' => 'gridfs#thumb_avatar', constraints: { filename: /thumb.*/ }
```

## Version differences

| Version  | Notes                                                                           |
|----------|---------------------------------------------------------------------------------|
| ~> 0.7.0 | ([compare][compare-0.7], [dependencies][deps-0.7]) Mongoid 3 & 4, bug fixes     |
| ~> 0.6.0 | ([compare][compare-0.6], [dependencies][deps-0.6]) Mongoid 3 & 4, bug fixes     |
| ~> 0.5.0 | ([compare][compare-0.5], [dependencies][deps-0.5]) Mongoid::Paranoia support    |
| ~> 0.4.0 | ([compare][compare-0.4], [dependencies][deps-0.4]) Carrierwave bump             |
| ~> 0.3.0 | ([compare][compare-0.3], [dependencies][deps-0.3]) Mongoid >= 3.0               |
| ~> 0.2.0 | ([compare][compare-0.2], [dependencies][deps-0.2]) Rails >= 3.2, Mongoid ~> 2.0 |
| ~> 0.1.0 | ([compare][compare-0.1], [dependencies][deps-0.1]) Rails <= 3.1                 |

[compare-0.7]: https://github.com/carrierwaveuploader/carrierwave-mongoid/compare/v0.6.3...v0.7.1
[compare-0.6]: https://github.com/carrierwaveuploader/carrierwave-mongoid/compare/v0.5.0...v0.6.3
[compare-0.5]: https://github.com/carrierwaveuploader/carrierwave-mongoid/compare/v0.4.0...v0.5.0
[compare-0.4]: https://github.com/carrierwaveuploader/carrierwave-mongoid/compare/v0.3.1...v0.4.0
[compare-0.3]: https://github.com/carrierwaveuploader/carrierwave-mongoid/compare/v0.2.1...v0.3.1
[compare-0.2]: https://github.com/carrierwaveuploader/carrierwave-mongoid/compare/v0.1.7...v0.2.2
[compare-0.1]: https://github.com/carrierwaveuploader/carrierwave-mongoid/compare/v0.1.1...v0.1.7

[deps-0.7]: https://rubygems.org/gems/carrierwave-mongoid/versions/0.7.1
[deps-0.6]: https://rubygems.org/gems/carrierwave-mongoid/versions/0.6.3
[deps-0.5]: https://rubygems.org/gems/carrierwave-mongoid/versions/0.5.0
[deps-0.4]: https://rubygems.org/gems/carrierwave-mongoid/versions/0.4.0
[deps-0.3]: https://rubygems.org/gems/carrierwave-mongoid/versions/0.3.1
[deps-0.2]: https://rubygems.org/gems/carrierwave-mongoid/versions/0.2.2
[deps-0.1]: https://rubygems.org/gems/carrierwave-mongoid/versions/0.1.7

### Changes from earlier versions of CarrierWave <= 0.5.6

CarrierWave used to have built-in Mongoid support. This gem replaces that
support and only supports Mongoid ~> 2.1

You can use `upload_identifier` to retrieve the original name of the uploaded file.

In the earlier version, the mount_uploader-method for mongoid had been defined
in lib/carrierwave/orm/mongoid. This code has been moved to
carrierwave/mongoid. If you update from earlier versions, don't forget to adjust
your require accordingly in your carrierwave-initializer.

The default mount column used to be the name of the upload column plus
`_filename`. Now it is simply the name of the column. Most of the time, the
column was called `upload`, so it would have been mounted to `upload_filename`.
If you'd like to avoid a database migration, simply use the `:mount_on` option
to specify the field name explicitly. Therefore, you only have to add a
`_filename` to your column name. For example, if your column is called
`:upload`:

```ruby
class Dokument
  mount_uploader :upload, DokumentUploader, mount_on: :upload_filename
end
```

## Known issues and limitations

Note that files mounted in embedded documents aren't saved when parent documents
are saved. By default, mongoid does not cascade callbacks on embedded
documents. In order to save the attached files on embedded documents, you must
either explicitly call save on the embedded documents or you must configure the
embedded association to cascade the callbacks automatically. For example:

```ruby
class User
  embeds_many :pictures, cascade_callbacks: true
end
```

You can read more about this [here](https://github.com/carrierwaveuploader/carrierwave/issues#issue/81)
