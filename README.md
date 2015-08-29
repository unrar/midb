# midb v0.0.2a :no_good: #

`midb` is **middleware for databases!** It helps you serve all the contents of your database via a simple API, and all
you have to do is write a JSON file! And it's written using the [RMVC framework](https://github.com/unrar/rmvc) :heart_eyes: :ok_hand:

## What can I do already?
midb is more functional everyday, but take it easy. Basically, you can do nothing as we still haven't created the gem.
When the first stable version is released, we'll create a branch for the gem, which will be the same code as this branch
(the development, friendlier one) but organized differently. 

As of v0.0.2a, you can see all the contents in a table. For example, you have a database named `test` with a table `users` 
and you want to create an API to list all the users. The fields are `uname` and `uage`, and the REQUIRED field `id`. Your `users.json` file should look like this:

```json
{
  "id":
  {
    "name": "users/uname",
    "age": "users/uage"
  }
}
```

You place this file in the `json` folder of your project, and set midb up to serve it:

```bash
$ midb serve users.json
$ midb start db:test
```

There we go, now you can go to `localhost:8081/users` and you'll get something like this:

```json
{
  "1":
  {
  "name":"joselo",
  "age":13
  },
  "2":
  {
  "name":"josefina",
  "age":43
  }
}
```

Beautiful, innit?