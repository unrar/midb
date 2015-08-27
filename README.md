# midb v0.0.1a :no_good: #

`midb` is **middleware for databases!** It helps you serve all the contents of your database via a simple API, and all
you have to do is write a JSON file! And it's written using the [RMVC framework](https://github.com/unrar/rmvc) :heart_eyes: :ok_hand:

## How does this work? 
Please keep in mind that midb is a baby project, I just started prototyping it and it's not even half ready for use yet.

The idea is that you can have a database (it will support many SQL and NoSQL engines) which you want (some) people to be 
able to read and modify. Instead of creating a rather complicated API that will only work for this app, you can use midb!

Say your database has a table named `USERS`, in the database `test`, with the columns `uname`, `uage` and `uid`. You want the API to be like this: `api.myapp.io/v1/users/1/name`, or `/age`. So tough, right? Well, midb is here to help! Create a JSON file like this:

```
{
  "name": "users/uname",
  "age": "users/uage",
  "id": "users/uid" 
}
```

(Note that the `id` is for internal use only, there won't be an `/id` endpoint)

That's it! Then you just place this file in the `/json` folder of your midb project, and set it all up:

    $ midb serve users.json
    $ midb start db:test

That's it! Keep in mind this is only a prototype as the project has just been started, but that's sort of how
it'll work.