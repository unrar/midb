# midb v0.0.4a :no_good: #

`midb` is **middleware for databases!** It helps you serve all the contents of your database via a simple API, and all
you have to do is write a JSON file! And it's written using the [RMVC framework](https://github.com/unrar/rmvc) :heart_eyes: :ok_hand:

## Setup
If you use SQLite3 as your database, you don't really have to set anything up. Just make sure to put your `file.db` under the `db/` directory, and specify the database name when starting the server (`midb start db:file`).

If you want to use MySQL, you have to set a few settings up:

```bash
$ midb set db:host localhost # the database host
$ midb set db:user root      # the database user
$ midb set db:password woot  # the user's password
$ midb set db:engine mysql   # tell midb to use mysql
```

Afterwards, the process is the same for every engine. Add endpoints pointing to your JSON schemes with `midb serve file.json`, and just start the server with `midb start db:mydatabase`!

## What can I do already?
midb is more functional everyday, but take it easy. Basically, you can do nothing as we still haven't created the gem.
When the first stable version is released, we'll create a branch for the gem, which will be the same code as this branch
(the development, friendlier one) but organized differently. 

As of v0.0.3a, you can see all the contents in a table. For example, you have a database named `test` with a table `users` 
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

## midb JSON syntax
midb uses a special JSON syntax, which is quite simple. The only rule you MUST follow is that *there must be
an ID field, named "id", in all the tables you want to use*. It's that simple. In future releases, we'll let
you change the name of the column, but at the moment there's no choice.

In the served `.json` files, you're explaining the structure of your database, and how it relates to the API that'll
be built. To do so, consider the JSON file an example response of ONE row of your database (one user, one client...).

In the keys, you provide the human-friendly name of the field, used in the response JSON and in the API. In the values,
you tell midb how to find the value in your database, using a very simple syntax: `table_name/field_name`. It's that simple!

As of v0.0.3a, though, you can also specify **relations** between tables. Say you have a table `employees` and a table `passwords`. The `employees` table contains their information, like the name (`ename`) and the salary (`esalary`), along with their `id`. The `passwords` table contains the passwords for the employees to login to your site, but they're not stored in the same order - the password with ID 1 doesn't necessarily belong to the employee with ID 1. So you add a field `password` containing the password, and a field `eid` containing the ID of the employee, that points to the main table (employees).

**NOTE**: The "main table" is always the one specified in the first JSON field, in this example `employees`.

How do you tell midb that? Very simply, using an easy notation: `passwords/password/eid->id`. That is, your first specify the table, then the field you want to get, then the field you want to link, and after the `->` the field in the main table. 

See this JSON example:

```json
{
  "id":
  {
    "name": "employees/ename",
    "salary": "employees/esalary",
    "age": "employees/eage",
    "password": "passwords/password/eid->id"
  }
} 
```
