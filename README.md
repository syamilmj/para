# Para

[![Hex.pm](https://img.shields.io/hexpm/v/para.svg)](https://hex.pm/packages/para)
[![Build Status](https://github.com/syamilmj/para/actions/workflows/ci.yml/badge.svg?name=CI)](https://github.com/syamilmj/para/actions)

Para is an Elixir library that provides structured and declarative way to parse and validate parameters.

Para uses Ecto under the hood and therefore inherits most of its utilities such as changeset and built-in validators.

## Why use Para?

When building API endpoints that deal with a lot of parameters, it is sometimes not enough to just rely on database schema for parsing and validation. A lot of times the HTTP parameters do not always represent the final form of the data that gets sent to the database.

![Pipeline](https://user-images.githubusercontent.com/845515/131730786-61c360bd-43ca-4dbc-a0ce-b3a283eeb3cb.png)

Para is meant to be implemented as part of your data processing pipeline, typically between *external source to internal services*. Using Para in this way avoids having to contaminate your controllers and internal services with repetitive inputs parsing and validations. It should also make testing a lot easier.

Para also allows you to define *multiple schemas* inside the same module to promote consistency between your schema and controller files, resulting in better code organizations.

## Usage

Add Para as a dependency in your `mix.exs` file.

```
def deps do
  [{:para, "~> 0.3"}]
end
```

### Examples

First, let's define your parameters schema

```elixir
defmodule Web.UserParams do
  use Para

  validator :create do
    required :name, :string
    required :age, :integer
    required :email, :string
    optional :phone, :string
  end

  validator :update do
    required :name, :string
    required :age, :integer
    required :email, :string
    optional :phone, :string, droppable: true
  end
end
```

You can now use this module as a validator in your controller

```elixir
defmodule Web.UserController do
  use Web, :controller
  alias Web.UserParams, as: Params

  def create(conn, params) do
    with {:ok, data} <- Params.validate(:create, params) do
      # ...
    end
  end

  def update(conn, params) do
    with {:ok, data} <- Params.validate(:update, params) do
      # ...
    end
  end
end
```

## Advanced Usage

Para supports all of Ecto's built-in validators, while also allowing custom validator functions and callbacks.

### Using Ecto's built-in validator as inline validator

To use an inline validator, use the `:validator` option, as such:

```elixir
validator :create do
  required :name, :string, [validator: {validate_length: [max: 30]}]
end
```

In the example above we're using Ecto's [`validate_length/3`](https://hexdocs.pm/ecto/Ecto.Changeset.html#validate_length/3) functions to validate the length of of the `:name` parameter.

### Custom inline validator

A custom validator function accepts 3 arguments

```elixir
def validate_age(change, field, opts) do
  ...
end
```

You can then use it as a custom inline validator:

```elixir
validator :update do
  required :age, :integer, validator: :validate_age
end
```

or supply it with options:

```elixir
validator :update do
  required :age, :integer, validator: {:validate_age, [less_than: 60]}
end
```

For more advanced usage, please refer to the [docs](https://hexdocs.pm/para/)
