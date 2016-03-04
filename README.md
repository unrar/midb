# midb v2.0.0 :no_good: 

[![Gem Version](https://badge.fury.io/rb/midb.svg)](http://badge.fury.io/rb/midb) [![Build Status](https://travis-ci.org/unrar/midb.svg)](https://travis-ci.org/unrar/midb) [![Inline docs](http://inch-ci.org/github/unrar/midb.svg?branch=gem&style=shields)](http://inch-ci.org/github/unrar/midb) [![Code Climate](https://codeclimate.com/github/unrar/midb/badges/gpa.svg)](https://codeclimate.com/github/unrar/midb) [![Scrutinizer Code Quality](https://scrutinizer-ci.com/g/unrar/midb/badges/quality-score.png?b=gem)](https://scrutinizer-ci.com/g/unrar/midb/?branch=gem) [![Test Coverage](https://codeclimate.com/github/unrar/midb/badges/coverage.svg)](https://codeclimate.com/github/unrar/midb/coverage)

`midb` is **middleware for databases!** It helps you serve all the contents of your database via a simple API, and all
you have to do is write a JSON file! And it's written using the [RMVC framework](https://github.com/unrar/rmvc) :heart_eyes: :ok_hand:

This is the second stable midb release. Other than some new interesting features and bug fixes, a lot of changes have taken place under the hood. However, next releases will focus on improving code quality and features for developers (like new hooks).

## Setup
Before doing anything, you have to bootstrap your midb project; this creates the few files that midb needs:

```bash
$ midb bootstrap
```

If you use SQLite3 as your database, you don't really have to set anything up. Just make sure to put your `file.db` under the `db/` directory.

If you want to use MySQL, you have to set a few settings up:

```bash
$ midb set db:host localhost # the database host
$ midb set db:user root      # the database user
$ midb set db:password woot  # the user's password
$ midb set db:engine mysql   # tell midb to use mysql
```

Afterwards, the process is the same for every engine. Add endpoints pointing to your JSON schemes with `midb serve file.json`, and start the server:

```bash
$ midb start db:database [port:xxxx]
```

Keep in mind that, if using SQLite, you only need to specify the database filename without the extension, as the .db extension is assumed. The default port is `8081`.

It's recommended that you change the default private API key (`midb-api`), which is used in POST, PUT and DELETE requests by default (see **Authentication** at wiki):

```bash
$ midb set api:key mynewapikey
```

It's also possible to specify whether the API key is needed for each HTTP method:

```bash
$ midb set privacy:get true   # Require authentication for GET methods
$ midb set privacy:post false # But don't for POST requests
```

This is available for all the methods supported by midb (`privacy:get`, `privacy:post`, `privacy:put` and `privacy:delete`). It is also possible to specify a different API key for GET requests (if `privacy:get` is set to `true`). For example:

```bash
$ midb set privacy:get true # Enable authentication on GET requests
$ midb set api:key private  # Global API key
$ midb set api:getkey openaccess # This key will be used for GET
$ midb set api:getkey nil   # nil = no key, use the global api:key
```

## Working with midb
The point of midb is that you barely have to write anything - you just need to tweak the settings so midb can connect to your database and write the JSON scheme(s) for your endpoints.

For a more detailed specification you can check the wiki, but essentially the point of the JSON files is to map an API endpoint like `api.io/users/5` to your database, like maybe the row with id 5 of the table `current_users`. Think of the JSON files like a template - they are a scheme of the replies and requests your API will perform. 

The only mandatory requisite of the JSON files is that **it must have an "id" key**, which has the whole structure/scheme as a value. This means your tables **MUST** have an `id` column (this will probably be changed in upcoming releases).

Another feature of the later releases is that you can set relations between tables. For instance, imagine a table `users` and another table `passwords`. It's not useful to create two separate endpoints, as each password belongs to a user.

The midb JSON syntax is rather simple. Given an API GET request `/api/resource/field`, it follows this structure (the first row being a regular table-mapping and the second one a cross-table relation):

`resource.json`

```json
{
  "id":
  {
  "field": "table_name/field",
  "second_field": "second_table/field/field_to_match->to_his_field_in_main_table"
  }
}
```

The second row can look quite confusing; it might look clearer in an illustrative example.

In this example, we set a column `uid` in the `passwords` table, which contains the ID of the user whose password is stored in the `password` column. 

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

This means that the `password` field must be looked up in the `passwords` table, and is located in the `password` column of the row whose `uid` column matches the `id` column of the row we're looking upin the main table (`users`). **The main table is the once where the first field of the JSON file is located**.

## API syntax

A midb API's syntax is quite universal, as it's a pretty simple CRUD API (though easily customizable with hooks). The supported methods, as described below, are the GET, POST, PUT and DELETE HTTP verbs.

### GET requests

GET requests can be performed in many different ways. Firstly, you can retrieve the whole table(s) as specified in the scheme by performing a GET request on the endpoint:

```
> GET /users
>> {"1": {"name": "Bob", "age": 31, "password": "stalker"}, "2": {"name": "josh", "age": 14, "password": "kiddo"}, "3": {"name": "amy", "age": 16, "password": "ifuseekamy"}}
```

Secondly, it's also possible to get a single row that matches a given id (remember the main table must have an `id` column):

```
> GET /users/3
>> {"3": {"name": "amy", "age": 16, "password": "ifuseekamy"}}
```

It's also possible to retrieve only a field if you specify it after the endpoint:

```
> GET /users/name
>> {"1": {"name": "Bob"}, "2": {"name": "josh"}, "3": {"name": "amy"}}
```

Finally, you can search for entries where a given field matches a pattern (a standard SQL `LIKE` pattern, keep in mind that it's queried as `... WHERE x LIKE '%pattern%';` so you don't need to add the `%` signs):

```
> GET /users/name/o
>> {"1": {"name": "Bob", "age": 31, "password": "stalker"}, "2": {"name": "josh", "age": 14, "password": "kiddo"}}
```

If the `privacy:get` setting is turned on, authentication will be requested for any kind of GET request. The HMAC digest must be a digest of the endpoint **WITHOUT** the other parameters (i.e. the JSON filename without the extension), in this example `users`. The key to be used is the general API key (`api:key`) by default, but if a GET-specific key is specified in the `api:getkey` setting, that one must be used.

curl example of authentication, using the `hmac.rb` script in the `utils` directory:

```bash
./hmac.rb users mykey # => [hmac digest] CqbUYblgN2Gl43YZnStvkNlJcVw%3D%0A (this script is hypothetical)
curl -H "Authentication: hmac CqbUYblgN2Gl43YZnStvkNlJcVw%3D%0A" http://localhost:8081/users/3
```

### POST requests
When performing one, it's necessary to provide a request body that includes all the fields in the JSON scheme, using the names therein defined. 

Authentication is omitted in this example: 

```
> POST /users name=lola&age=17&password=jfchrist
>> {"status": "201 Created", "id": 4}
```

### PUT requests
The body must contain only the fields present in the JSON scheme that want to be changed; not necessarily all of them. The ID of the entry to be edited must also be included after the endpoint.

```
> PUT /users/3 name=Amy&age=21
>> {"status": "200 OK"}

> GET /users/3
>> {"3": {"name": "Amy", "age": 21, "password": "ifuseekamy"}}
```

### DELETE requests
The ID must be specified after the endpoint. As with GET requests, if authentication is turned on then the object of the HMAC digest must be the endpoint.

```
> DELETE /users/3
>> {"status": "200 OK"}
```

## Authentication 101
midb uses HTTP HMAC authentication, through a private key. Authentication is not enabled on GET requests by default, unlike on POST/PUT/DELETE requests

In order to authenticate, an `Authentication` HTTP header must be sent with each request, following this structure: `Authentication: hmac MY_DIGEST`.

The digest can be easily created with any HMAC-SHA1 library (in ruby: `HMAC::SHA1.new(key).update(string_to_encode).digest`) and further encoded to base64 and properly escaped (in ruby: `CGI.escape(Base64.encode64(digest)))`). A tool is also provided to create a digest from the terminal: `./utils/hmac.rb string_to_encode key`.

In GET and DELETE requests, the endpoint (that is, the json file minus the extension) is the string that has to be encoded; whereas, on POST and PUT requests, the string to encode is the body of the request (as a query string). The API key is the one stored in `api:key`, or alternatively `api:getkey` in GET requests if not nil. 

This is an example of an authenticated GET and POST request through curl:

```bash
# For the GET request, we encode the endpoint only
$ ./utils/hmac.rb users example
[hmac digest] CqbUYblgN2Gl43YZnStvkNlJcVw%3D%0A

$ curl -H "Authentication: hmac CqbUYblgN2Gl43YZnStvkNlJcVw%3D%0A" http://localhost:8081/users
{"1":{"name":"test","age":30,"password":"test1"},"2":{"name":"test2","age":60,"password":"test2"},"3":{"name":"unrar","age":17,"password":"yes_i_can!"}}

# For the POST request, we encode the body
$ ./utils/hmac.rb name=pep\&age=40\&password=cata example
[hmac digest] 0NLpB0%2BucPuYSuyxDSFKEo9QyRc%3D%0A

$ curl -H "Authentication: hmac  0NLpB0%2BucPuYSuyxDSFKEo9QyRc%3D%0A" --data "name=pep&age=40&password=cata" -X POST http://localhost:8081/users
{"status":"201 created","id":4}
```


The following is an example of a simple client, taken from the test `client.rb` and using `httpclient`:

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

## API customization
If you want to run an API you most likely are a developer of some sort - and if you're using this ruby solution to your API
madness, you most likely know some ruby. As of v1.1.0, creating your custom own API is getting easier!

It's easy to understand how MIDB internally works - although out of the scope of this README, but we're working on the wiki. The code is pretty well-documented (although soon to be improved), but not much understanding of all the internal classes and modules is required to write a MIDB API in a file. You just have to create a `MIDB::API::Engine` object and supply it with a configuration hash.

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

If you load a file that overrides hooks as well, you can have your custom MIDB API! K

### Hooks so far
As of v2.0.0, there are two hooks available: 

* `after_get_all_entries`, ran after the `get_all_entries` method in the server model.
* `format_field`, ran when returning the JSON response to a GET request.

More hooks are the main focus of upcoming releases, and I'm working on several wiki pages that go through this deeply.

Briefly, the point of hooks is to supply midb with functions that will be ran on different contexts; that is, if you hook a function to `format_field`, it will be ran when midb returns a GET request as JSON.

There are several ways to use hooks, which can only be used when running midb from a ruby file. This is again furtherly discussed in the wiki, but given a file like the one described above, the hooks can be registered before the server is started:

```ruby
engine.hooks.register("hook_name", :my_function)
engine.start
```

The hooks implementation is [its_hookable](https://github.com/unrar/its_hookable)'s.
