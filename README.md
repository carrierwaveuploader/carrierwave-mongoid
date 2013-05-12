# CarrierWave for Mongoid [![Gem Version](https://badge.fury.io/rb/carrierwave-mongoid.png)](http://badge.fury.io/rb/carrierwave-mongoid) [![Build Status](https://travis-ci.org/jnicklas/carrierwave-mongoid.png?branch=master)](http://travis-ci.org/jnicklas/carrierwave-mongoid) [![Code Climate](https://codeclimate.com/github/jnicklas/carrierwave-mongoid.png)](https://codeclimate.com/github/jnicklas/carrierwave-mongoid)

This gem adds support for Mongoid and MongoDB's GridFS to
[CarrierWave](https://github.com/jnicklas/carrierwave/)

This functionality used to be part of CarrierWave but has since been extracted
into this gem.

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

## Getting Started

Follow the "Getting Started" directions in the main
[Carrierwave repository](https://raw.github.com/jnicklas/carrierwave/).

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

Since GridFS doesn't make the files available via HTTP, you'll need to stream
them yourself. In Rails for example, you could use the `send_data` method. You
can optionally tell CarrierWave the URL you will serve your images from,
allowing it to generate the correct URL, by setting eg:

```ruby
CarrierWave.configure do |config|
  config.grid_fs_access_url = "/systems/uploads"
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

## Version differences

| Version  | Notes                                                                           |
|----------|---------------------------------------------------------------------------------|
| ~> 0.6.0 | ([compare][compare-0.6], [dependencies][deps-0.6]) Mongoid 3 & 4, bug fixes     |
| ~> 0.5.0 | ([compare][compare-0.5], [dependencies][deps-0.5]) Mongoid::Paranoia support    |
| ~> 0.4.0 | ([compare][compare-0.4], [dependencies][deps-0.4]) Carrierwave bump             |
| ~> 0.3.0 | ([compare][compare-0.3], [dependencies][deps-0.3]) Mongoid >= 3.0               |
| ~> 0.2.0 | ([compare][compare-0.2], [dependencies][deps-0.2]) Rails >= 3.2, Mongoid ~> 2.0 |
| ~> 0.1.0 | ([compare][compare-0.1], [dependencies][deps-0.1]) Rails <= 3.1                 |

[compare-0.6]: https://github.com/jnicklas/carrierwave-mongoid/compare/v0.5.0...v0.6.0
[compare-0.5]: https://github.com/jnicklas/carrierwave-mongoid/compare/v0.4.0...v0.5.0
[compare-0.4]: https://github.com/jnicklas/carrierwave-mongoid/compare/v0.3.1...v0.4.0
[compare-0.3]: https://github.com/jnicklas/carrierwave-mongoid/compare/v0.2.1...v0.3.1
[compare-0.2]: https://github.com/jnicklas/carrierwave-mongoid/compare/v0.1.7...v0.2.2
[compare-0.1]: https://github.com/jnicklas/carrierwave-mongoid/compare/v0.1.1...v0.1.7

[deps-0.6]: https://rubygems.org/gems/carrierwave-mongoid/versions/0.6.0
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

You can read more about this [here](https://github.com/jnicklas/carrierwave/issues#issue/81)
