# midb v1.1.0 :no_good: 

[![Gem Version](https://badge.fury.io/rb/midb.svg)](http://badge.fury.io/rb/midb) [![Build Status](https://travis-ci.org/unrar/midb.svg)](https://travis-ci.org/unrar/midb) [![Inline docs](http://inch-ci.org/github/unrar/midb.svg?branch=gem&style=shields)](http://inch-ci.org/github/unrar/midb) [![Code Climate](https://codeclimate.com/github/unrar/midb/badges/gpa.svg)](https://codeclimate.com/github/unrar/midb) [![Scrutinizer Code Quality](https://scrutinizer-ci.com/g/unrar/midb/badges/quality-score.png?b=gem)](https://scrutinizer-ci.com/g/unrar/midb/?branch=gem) [![Test Coverage](https://codeclimate.com/github/unrar/midb/badges/coverage.svg)](https://codeclimate.com/github/unrar/midb/coverage)

`midb` is **middleware for databases!** It helps you serve all the contents of your database via a simple API, and all
you have to do is write a JSON file! And it's written using the [RMVC framework](https://github.com/unrar/rmvc) :heart_eyes: :ok_hand:

This is the first stable release of midb! Because now it's a gem, the structure of the project has changed quite a bit. To see the old (0.0.x) draft-releases, check out the `master` branch - but from now on, everything is going to happen in the `gem` branch!

## Setup
Before doing anything, you have to bootstrap your midb project!

```bash
$ midb bootstrap
```

If you use SQLite3 as your database, you don't really have to set anything up. Just make sure to put your `file.db` under the `db/` directory, and specify the database name when starting the server (`midb start db:file`).

If you want to use MySQL, you have to set a few settings up:

```bash
$ midb set db:host localhost # the database host
$ midb set db:user root      # the database user
$ midb set db:password woot  # the user's password
$ midb set db:engine mysql   # tell midb to use mysql
```

Afterwards, the process is the same for every engine. Add endpoints pointing to your JSON schemes with `midb serve file.json`, and just start the server with `midb start db:mydatabase`!

You probably want to change the default private API key (`midb-api`), which is used in POST, PUT and DELETE requests (see **Authentication** at wiki):

```bash
$ midb set api:key mynewapikey
```

## Working with midb
The point of midb is that you barely have to write anything - just tweak the settings so it works with your database, write a couple JSON files and you're done!

For a more detailed specification you can check the wiki, but long story short the point of the JSON files is to map and API endpoint like `api.io/users/5` to your database, like maybe the row with id 5 of the table `current_users`. Think of the JSON files like a template - they are a scheme of the replies your API will send to GET requests, and of the POST/PUT requests.

The only mandatory requisite of the JSON files is that **it must have an "id" key**, which has the whole structure/scheme as a value. This means your tables MUST have an `id` column.

Another feature of the later releases is that you can set relations between tables. For instance, imagine you have a table `users` and a table `passwords`. You don't really want to create two separate endpoints, as the passwords are linked to your users. So what to do you? 

In this example, we set a column `uid` in the `passwords` table, that contains the ID of the user whose password is in the `password` column. Great! But how do we tell midb that? 
We use a very simple syntax. First, regular-old midb syntax: `table_name/column_name`. But then, if you want to link it to another field, you do it like this: `this_field->main_table_field`. This means: *this field must match this other field, which is in the main table*. **The main table is the one stated in the first key of the scheme**.

The JSON file resulting from our example would look as follows:

`users.json`

```json
{
  "id":
  {
  "name": "users/uname",
  "age": "users/uage",
  "password": "passwords/password/uid->id"
  }
}
```

Then, we'd start the server (`$ midb start db:dbName`) and we'd obtain a pretty nice REST API running on our 8081 port. Using `client.rb` (with a little tweaking, as it's meant only for testing purposes and all values are set for my example/test API) we could have a conversation like this:

```
> GET /users
>> {"1": {"name": "Bob", "age": 31, "password": "stalker"}, "2": {"name": "josh", "age": 14, "password": "kiddo"}}

> POST /users name=amy&age=16&password=ifuseekamy
>> {"status": "201 Created", "id": 3}

> GET /users/3
>> {"3": {"name": "amy", "age": 16, "password": "ifuseekamy"}}

> PUT /users/3 name=Amy&age=21
>> {"status": "200 OK"}

> GET /users/3
>> {"3": {"name": "Amy", "age": 21, "password": "ifuseekamy"}}

> DELETE /users/3
>> {"status": "200 OK"}
```

All of that, without doing much more than writing a JSON file!

## Authentication 101
midb uses HTTP HMAC authentication, through a private key. In GET requests, authentication is not used, but in POST/PUT/DELETE requests you must be authenticated or you'll get a 401 error. 

How do we authenticate? It's quite easy. We have to send the server an `Authentication` HTTP request, following this structure: `Authentication: hmac MY_DIGEST`.

Oh, boy, what that digest thing? It's easy. You have to create an HMAC of **your request's body** (the data you're sending to the server, usually it's just a query string) using the private API key that you've previously set on the server using `midb set api:key`.

Here's an example, taken from my test `client.rb` and using `httpclient`:

```ruby
require 'httpclient'
require 'hmac-sha1'
require 'base64'
require 'cgi'
require 'uri'

def create_header(body)
  key = "midb-api" ## Default API key - change this with yours!
  signature = URI.encode_www_form(body) # Turns the POST params into an encoded query string
  hmac = HMAC::SHA1.new(key)
  hmac.update(signature)
  {"Authentication" =>"hmac " + CGI.escape(Base64.encode64("#{hmac.digest}"))}
end

c = HTTPClient.new

# Insert something
body = {"name" => "unrar", "age" => 17, "password" => "can_you_not!"}
header = create_header(body)
res = c.post("http://localhost:8081/test/", body=body, header=header)
```

This is of course an example - HMAC HTTP authentication is widely used, but I've only tested this method in the example as I'm 100% it'll work because the server does the same (that's the point of HMAC authentication).

## For the devs!
If you want to run an API you most likely are a developer of some sort - and if you're using this ruby solution to your API
madness, you most likely know some ruby. As of v1.1.0, creating your custom own API is getting easier! While hooks are not 
yet fully implemented (see the `addin.rb` and `hooked.rb` files), you can create an API using the MIDB::API module. 

Here's how:

```ruby
require 'midb'

# If you want to bypass the controller (which is used by the binary), you need to do this

# First, create a config hash
cc = Hash.new
# We're using SQLite3, so we only need to specify the engine and endpoints
cc["dbengine"] = :sqlite3
cc["serves"] = ["users.json"] # file in ./json/
# Init the engine, given db='test' and starting HTTP status=420 WAIT
engine = MIDB::API::Engine.new("test", "420 WAIT", cc)
engine.start()
```

If you load a file that overrides hooks as well, you can have your custom MIDB API! 

Don't be hard on us for this not being *much* useful yet; it's officially coming on v2.0.0!