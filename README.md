# CarrierWave for Mongoid

This gem adds support for Mongoid and MongoDB's GridFS to CarrierWave, see the
CarrierWave documentation for more detailed usage instructions.

### This version supports ONLY version of mongoid ~> 2.1
Keep in mind that if you came up from previous versions you should make a few steps to go with it:

* change(rename in db) field name from `avatar_name` to `avatar`(appropriate to your uploader name)
* fix you code where you need to operate with uploaded file's filename from `avatar` to `avatar_identifier`

Install it like this:

    gem install carrierwave-mongoid

Use it like this:

```ruby
require 'carrierwave/mongoid'
```

Make sure to disable auto_validation on the mounted column.

Using bundler:

```ruby
gem 'carrierwave-mongoid', :require => 'carrierwave/mongoid'
```

This used to be part of CarrierWave but has been extracted.

## Using MongoDB's GridFS store

You'll need to configure the database and host to use:

```ruby
CarrierWave.configure do |config|
  config.grid_fs_database = 'my_mongo_database'
  config.grid_fs_host = 'mongo.example.com'
end
```

The defaults are `carrierwave` and `localhost`.

And then in your uploader, set the storage to `:grid_fs`:

```ruby
class AvatarUploader < CarrierWave::Uploader::Base
  storage :grid_fs
end
```

Since GridFS doesn't make the files available via HTTP, you'll need to stream
them yourself. In Rails for example, you could use the `send_data` method. You
can tell CarrierWave the URL you will serve your images from, allowing it to
generate the correct URL, by setting eg:

```ruby
CarrierWave.configure do |config|
  config.grid_fs_access_url = "/image/show"
end
```

## Known issues/ limitations

If using Mongoid, note that embedded documents files aren't saved when parent documents are saved.
You must explicitly call save on embedded documents in order to save their attached files.
You can read more about this [here](https://github.com/jnicklas/carrierwave/issues#issue/81)
