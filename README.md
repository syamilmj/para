# Para

[![Hex.pm](https://img.shields.io/hexpm/v/para.svg)](https://hex.pm/packages/para)

Para is an Elixir library that provides structured and declarative way to parse and validate parameters.

Para uses Ecto under the hood and therefore inherits most of its utilities such as changeset and built-in validators.

### Why use Para?

When building API endpoints that deal with a lot of parameters, it is sometimes not enough to just rely on Ecto schema for parsing and validation. A lot of times the HTTP parameters do not always represent the final form of the data that gets sent to the database.

![Pipeline](https://user-images.githubusercontent.com/845515/131730786-61c360bd-43ca-4dbc-a0ce-b3a283eeb3cb.png)

Para is meant to be implemented as part of your data processing pipeline, typically between external source to internal services. Using Para in this way avoids having to contaminate your controllers and internal services with repetitive inputs parsing and validations. It should also make testing a lot easier.

Para also allows you to define multiple schemas inside the same module to promote consistency between your schema and controller files, resulting in better code organizations.

### Usage

Add Para as a dependency in your `mix.exs` file.

```
def deps do
  [{:para, "~> 0.1"}]
end
```

After you are done, run `mix deps.get` in your shell to fetch and compile Para.

### Examples

First, let's define your parameters schema

```elixir
defmodule Web.UserPara do
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
    optional :phone, :string
  end
end
```

You can now use this module as a validator in your controller

```elixir
defmodule Web.UserController do
  use Web, :schema
  alias Web.UserPara

  def create(conn, params) do
    with {:ok, data} <- UserPara.validate(:create, params) do
      # ...
    end
  end

  def update(conn, params) do
    with {:ok, data} <- UserPara.validate(:update, params) do
      # ...
    end
  end
end
```

For more advanced usage, please refer to the [docs](https://hexdocs.pm/para/)
