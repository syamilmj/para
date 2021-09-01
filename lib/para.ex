defmodule Para do
  @moduledoc """
  Para is an Elixir library that provides structured and
  declarative way of validating HTTP parameters.

  Para uses Ecto under the hood and therefore inherits most of
  its utilities such as changeset and built-in validators.

  ## Usage

  Let's imagine that you have a controller named `Web.FooController` and
  wanted to validate the parameters for its `:create` and `:update` actions

  First, let's define your parameters schema

      defmodule Web.FooPara do
        use Para

        validator :create do
          required :name, :string
          required :age, :integer
          required :email, :string
          optional :phone, :string
        end

        validator :update do
          optional :name, :string
          optional :age, :integer
          optional :email, :string
          optional :phone, :string
        end
      end

  You can now use this module as a validator in your controller

      defmodule Web.FooController do
        use Web, :schema
        alias Web.FooPara

        def create(conn, params) do
          with {:ok, data} <- FooPara.validate(:create, params) do
            # ...
          end
        end
      end

  ## Inline validators

  Inline validator is a convenient way to validate your fields. This is
  especially useful when you need to perform some basic validation
  using `Ecto.Changeset`'s built-in validators.

      defmodule PhonePara do
        use Para

        validator :update do
          required :name, :string, validator: {:validate_length, [min: 3, max: 100]}
        end
      end

  You can also use custom inline validators by supplying the function name as
  as an atom.

      defmodule PhonePara do
        use Para

        validator :update do
          required :age, :string, validator: :validate_age
        end

        def validate_age(changeset, params) do
          # ...
        end
      end

  ## Callback validator

  Sometimes, you might want to use custom validators or need to perform
  additional data manipulations. For this, you can use the `callback/1` macro.

  The `callback/1` macro will always be the last function to be called
  after the validator has parsed and validated the parameters.

      defmodule Web.FooPara do
        use Para

        validator :create do
          required :name, :string
          required :age, :integer
          required :email, :string
          optional :phone, :string
          callback :create_validators
        end

        def create_validators(changeset, params) do
          changeset
          |> format_email(params)
          |> format_phone(params)
          |> validate_age()
        end

        def format_email(changeset, params) do
          # ...
        end

        def format_phone(changeset, params) do
          # ...
        end

        def validate_age(changeset) do
          # ...
        end
      end

  """

  @type t :: {:ok, map()} | {:error, Ecto.Changeset.t()}

  @doc """
  Defines a validator schema with an action name and field definitions.

  This will generate a new function called `validate/2` with the action `name`
  and `params` as the arguments.

      iex> defmodule UserPara do
      ...>   use Para
      ...>
      ...>   validator :create do
      ...>     required :name
      ...>   end
      ...> end
      ...>
      ...> UserPara.validate(:create, %{"name" => "Syamil MJ"})
      {:ok, %{name: "Syamil MJ"}}

  """
  defmacro validator(name, do: block) do
    blocks =
      case block do
        {:__block__, [], blocks} -> blocks
        block -> [block]
      end

    quote do
      def validate(unquote(name), params) do
        Para.validate(__MODULE__, unquote(blocks), params)
      end
    end
  end

  @doc false
  def validate(module, blocks, params) do
    spec =
      blocks
      |> discard_droppable_fields(params)
      |> Enum.reduce(%{}, fn
        {:required, name, type, opts}, acc ->
          acc
          |> put_in([Access.key(:data, %{}), name], opts[:default])
          |> put_in([Access.key(:types, %{}), name], type)
          |> put_in([Access.key(:required, [])], Map.get(acc, :required, []) ++ [name])
          |> assign_inline_validators(name, opts)

        {:optional, name, type, opts}, acc ->
          acc
          |> put_in([Access.key(:data, %{}), name], opts[:default])
          |> put_in([Access.key(:types, %{}), name], type)
          |> assign_inline_validators(name, opts)

        _, acc ->
          acc
      end)

    callback =
      Enum.find_value(blocks, fn
        {:callback, name} -> name
        _ -> nil
      end)

    permitted = Map.keys(spec.data)

    changeset =
      {spec.data, spec.types}
      |> Ecto.Changeset.cast(params, permitted)
      |> Ecto.Changeset.validate_required(spec.required)
      |> apply_inline_validators(module, spec.validators)
      |> apply_callback(module, callback, params)

    case changeset do
      %{valid?: true} -> {:ok, Ecto.Changeset.apply_changes(changeset)}
      _ -> {:error, changeset}
    end
  end

  @doc """
  Define custom callback to perform any additional parsing or validation
  to the processed changeset or parameters
  """
  defmacro callback(name) do
    quote do
      {:callback, unquote(name)}
    end
  end

  @doc """
  Define a required field.

  ## Options

    * `:validator` - Define either one of the built-in Ecto.Changeset's validators
      or use your own custom inline validator. Refer: [Custom inline validator](#required/3-custom-inline-validator)

    * `:droppable` - Drop the field when the value is nil. This
      is especially true for actions like update where only specific fields are
      submitted instead of all the available fields.

  ## Custom inline validator

  You can define your own validator as such:

      def validate_country(changeset, field) do
        # ...
      end

  Then use it as an inline validator for your field

      validator :create do
        required :country, :string, [validator: :validate_country]
      end

  """
  defmacro required(name, type \\ :string, opts \\ []) do
    quote do
      {:required, unquote(name), unquote(type), unquote(opts)}
    end
  end

  @doc """
  Define an optional field.

  Similar to `required/3`, it also accepts the same Options
  """
  defmacro optional(name, type \\ :string, opts \\ []) do
    quote do
      {:optional, unquote(name), unquote(type), unquote(opts)}
    end
  end

  @doc false
  def discard_droppable_fields(blocks, params) do
    Enum.filter(blocks, fn
      {_, name, _, opts} ->
        with true <- opts[:droppable],
             false <- Map.has_key?(params, Atom.to_string(name)) do
          false
        else
          _ -> true
        end

      any ->
        any
    end)
  end

  @doc false
  def assign_inline_validators(spec, name, opts) do
    validators = spec[:validators] || %{}

    if validator = opts[:validator] do
      put_in(spec, [Access.key(:validators, %{}), name], validator)
    else
      put_in(spec, [Access.key(:validators, %{})], validators)
    end
  end

  @doc false
  def apply_inline_validators(changeset, module, validators) do
    Enum.reduce(validators, changeset, fn {key, validator}, acc ->
      apply_inline_validator(acc, module, key, validator)
    end)
  end

  @doc false
  def apply_inline_validator(changeset, module, key, validator) do
    case validator do
      {function, data_or_opts} ->
        do_apply_inline_validator(module, function, [changeset, key] ++ [data_or_opts])

      {function, data, opts} ->
        do_apply_inline_validator(module, function, [changeset, key] ++ [data, opts])

      _ ->
        changeset
    end
  end

  @doc false
  def do_apply_inline_validator(module, function, params) do
    arity = length(params)

    if function_exported?(Ecto.Changeset, function, arity) do
      apply(Ecto.Changeset, function, params)
    else
      apply(module, function, params)
    end
  end

  @doc false
  def apply_callback(changeset, _, nil, _), do: changeset

  def apply_callback(changeset, module, callback, params) do
    apply(module, callback, [changeset, params])
  end

  defmacro __using__(_) do
    quote do
      import Para,
        only: [
          validator: 2,
          required: 1,
          required: 2,
          required: 3,
          optional: 1,
          optional: 2,
          optional: 3,
          callback: 1
        ]
    end
  end
end
