defmodule Para do
  @moduledoc """
  Build structured parameter validation service for web endpoints,
  typically in Phoenix/Plug based applications.

  ## Usage

  Let's imagine that you have a controller named `Web.FooController` and
  wanted to validate the parameters for its `:create` and `:update` actions

  1. Define your parameters schema

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

  2. You can now use this module as validator in your controller

      defmodule Web.FooController do
        use Web, :schema
        alias Web.FooPara

        def create(conn, params) do
          with {:ok, params} <- FooPara.validate(:create, params) do
            # ...
          end
        end
      end

  ## Custom validators

  Sometimes, you might require to use custom validators or perform
  additional data manipulations. For this, you can use the `callback` macro.

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

  defmacro validator(name, do: block) do
    {:__block__, [], blocks} = block

    quote do
      def validate(unquote(name), params) do
        Para.validate(__MODULE__, unquote(blocks), params)
      end
    end
  end

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

  defmacro callback(name) do
    quote do
      {:callback, unquote(name)}
    end
  end

  @doc """
  Define a required field

  ## Options

    * `:validator` - Define either one of the built-in Ecto.Changeset's validators
      or use your own custom inline validator. Please refer docs on [Custom inline validator](#required/3-custom-inline-validator)

    * `:droppable` - Drop the field when the value is nil. This
      is especially true for actions like update where only specific fields are
      submitted instead of all the available fields.

  ## Custom inline validator

  You can define your own validator as such:

      def validate_country(changeset, field) do
        # always return changeset
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
  Define an optional field
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

  def apply_inline_validators(changeset, module, validators) do
    Enum.reduce(validators, changeset, fn {key, validator}, acc ->
      apply_inline_validator(acc, module, key, validator)
    end)
  end

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

  def do_apply_inline_validator(module, function, params) do
    arity = length(params)

    if function_exported?(Ecto.Changeset, function, arity) do
      apply(Ecto.Changeset, function, params)
    else
      apply(module, function, params)
    end
  end

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
