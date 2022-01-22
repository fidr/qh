# Qh

Easy Rails-style query helper for iex. 

```elixir
use Qh

Qh.configure(app: :my_app)

q User.where(age > 20).limit(10).all
[%MyApp.User{age: 22, name: "Bob"}, ...]
```

## Installation

Add `qh` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:qh, "~> 0.2"}
  ]
end
```

Add to your `.iex.exs`:

```elixir
use Qh

Qh.configure(app: :my_app)
```

Make sure to change `:my_app` to your otp app name that holds the schema's and repo's.

## Usage

Most `Ecto.Query` and `Ecto.Repo` functions are supported.

 - Call by chaining query/repo functions
 - Specifying bindings is optional if you're fetching for a single schema. 
 - Pass a condition as binary to use custom fragments
 - Some added aliases for convenience

### Query examples

```elixir
# First/last
q User.first
q User.first(10)
q User.last
q User.last(1)

# Custom order
q User.order(name).last(3)
q User.order(name: :asc, age: :desc).last
q User.order("lower(?)", name).last

# Conditions
q User.where(age > 20 and age <= 30).count
q User.where(age > 20 and age <= 30).limit(10).all
q User.where(age > 20 or name == "Bob").all
q User.where(age > 20 and (name == "Bob" or name == "Anna")).all
q User.where(age: 20, name: "Bob").count
q User.where("nicknames && ?", ["Bobby", "Bobi"]).count
q User.where("? = ANY(?)", age, [20, 30, 40]).count

# Opional binding
q User.where([u], u.age > 20 and u.age <= 30).count

# Find
q User.get!(21)
# or
q User.find(21)

# Alias for where(...).first
q User.find_by(name: "Bob Foo")
q User.find_by(name == "Bob" or name == "Anna")

# Aggregations
q User.group_by("length(name)").count
q User.group_by(name).avg(age)

# Select stats
q User.select(count(), avg(age), min(age), max(age)).all

# Aggregate stats grouped by column
q User.group_by(name).aggr(%{count: count(), avg: avg(age), min: min(age), max: max(age)})

# Count number of messages per user
q User.left_join(:messages).group_by(id).count([u, m], m.id)

# Grab only users that have messages
q User.distinct(id).join(:messages).all

# Custom join logic
q User.join([u], u in MyApp.Messages, on: u.id == m.sent_by_id, as: :m)
```

## Configuration

 - `app`: App name that is used for infering the schema namespace and repo
 - `app_mod`: You can also set the app module directly, instead of the app name
 - `repo`: Set the repo module directly, in case of a non-default repo

Set via config:

```elixir
config :qh, app: :my_app, repo: MyApp.AlternateRepo
```

Set via configure:

```elixir
Qh.configure(app: :my_app, repo: MyApp.AlternateRepo)
```

Pass in options:

```elixir
user = q(User.find(21), app: :my_app, repo: MyApp.AlternateRepo)
```
