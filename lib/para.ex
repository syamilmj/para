defmodule Para do
  @moduledoc """
  Para is an Elixir library that provides structured and
  declarative way to parse and validate parameters.

  Para uses Ecto under the hood and therefore inherits most of
  its utilities such as changeset and built-in validators.

  ## Usage

  Let's imagine that you have a controller named `Web.UserController` and
  wanted to validate the parameters for its `:create` and `:update` actions.

  First, let's define your parameters schema.

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

  This will generate two `validate/2` functions for your module
  with action `name` and `params` as arguments.

      defmodule Web.UserController do
        use Web, :controller
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

  The `validate/2` function will return either an `{:ok, map}` or `{:error, changeset}`
  tuple.

  ## Inline validators

  Inline validator is a convenient way to validate your fields. This is
  especially useful when you need to perform some basic validation
  using `Ecto.Changeset`'s built-in validators.

      defmodule UserPara do
        use Para

        validator :update do
          required :name, :string, validator: {:validate_length, [min: 3, max: 100]}
        end
      end

  You can also use custom inline validators by supplying the function name
  as an atom. Custom inline validator will receive `changeset` and the
  original `params` as the arguments.

      defmodule UserPara do
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

      defmodule Web.UserPara do
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
  @type data :: %{atom => term}

  @doc """
  Parse and validate parameters for a given action.

  The function will cast all the returned map keys into atoms except
  for embedded map or list.

  ## Examples

      defmodule OrderPara do
        use Para

        validator :create do
          required :title
          required :data, {:array, :map}
        end
      end

      # Validate action with parameters
      OrderPara.validate(:create, %{
        "title" => "test"
        "data" => [%{"color" => "black", "material" => "cotton"}]
      })
      #=> {:ok, %{
        title: "test"
        data: [%{"color" => "black", "material" => "cotton"}]
      }}
  """
  @callback validate(atom, map) :: {:ok, data} | {:error, Ecto.Changeset.t()}

  @doc false
  defmacro __using__(_) do
    quote do
      @behaviour Para

      import Para,
        only: [
          validator: 2,
          required: 1,
          required: 2,
          required: 3,
          optional: 1,
          optional: 2,
          optional: 3,
          callback: 1,
          embeds_one: 2,
          embeds_many: 2
        ]
    end
  end

  @doc """
  Define a validator schema with an action name and field definitions.

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
    fields =
      case block do
        {:__block__, _, fields} -> fields
        block -> [block]
      end

    quote do
      def validate(unquote(name), params) do
        Para.validate(__MODULE__, unquote(fields), params)
      end
    end
  end

  @doc """
  Define a custom callback function that will be called to perform any
  additional manipulation to the changeset or parameters.

  The callback function must accept two arguments namely `changeset` and
  `params` and return an `Ecto.Changeset` struct.

  ## Examples

      # Define callback function to be called
      validator :create do
        callback :validate_price
      end

      def validate_price(changeset, params) do
        #...
      end
  """
  defmacro callback(name) do
    quote do
      {:callback, unquote(name)}
    end
  end

  @doc """
  Define a required field.

  ## Options

    * `:default` - Assign a default value if the not set by input parameters

    * `:validator` - Define either one of the built-in Ecto.Changeset's validators
      or use your own custom inline validator. Refer: [Custom inline validator](#required/3-custom-inline-validator)

    * `:droppable` - Drop the field when the key doesn't exist in parameters. This
      is useful when you need to perform partial update by leaving out certain fields.

  ## Custom inline validator

  You can define your own validator as such:

      def validate_country(changeset, field) do
        # ...
      end

  Then use it as an inline validator for your field

      validator :create do
        required :country, :string, [validator: :validate_country]
      end

  You can also supply options with your custom inline validator

      validator :create do
        required :country, :string, [validator: {:validate_country, region: :asia}]
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

  @doc """
  Define an embedded map field

  It accepts similar schema definition like `validator/2`.

  ## Examples

      defmodule ParentPara do
        use Para

        validator :create do
          embeds_one :child do
            optional :name, :string
            optional :age,  :integer
          end
        end
      end
  """
  defmacro embeds_one(name, do: block) do
    fields =
      case block do
        {:__block__, _, fields} -> fields
        block -> [block]
      end

    quote do
      {:embed_one, unquote(name), unquote(fields)}
    end
  end

  @doc """
  Define an embedded array of maps field.

  It accepts similar schema definition like `validator/2`.

  ## Examples

      defmodule OrderPara do
        use Para

        validator :create do
          embeds_many :items do
            required :title
            required :price, :float
          end
        end
      end
  """
  defmacro embeds_many(name, do: block) do
    fields =
      case block do
        {:__block__, _, fields} -> fields
        block -> [block]
      end

    quote do
      {:embed_many, unquote(name), unquote(fields)}
    end
  end

  @doc false
  def validate(module, fields, params) do
    case changeset = do_validate(module, fields, params) do
      %{valid?: true} -> {:ok, apply_changes(changeset)}
      _ -> {:error, changeset}
    end
  end

  @doc false
  def do_validate(module, fields, params) do
    spec = build_spec(fields, params)

    callback =
      Enum.find_value(fields, fn
        {:callback, name} -> name
        _ -> nil
      end)

    {spec.data, spec.types}
    |> Ecto.Changeset.cast(params, spec.permitted)
    |> Ecto.Changeset.validate_required(spec.required)
    |> validate_embeds(module, spec)
    |> apply_inline_validators(module, spec.validators)
    |> apply_callback(module, callback, params)
  end

  @doc false
  def build_spec(fields, params) do
    default = %{data: %{}, types: %{}, embeds: %{}, permitted: [], required: [], validators: %{}}

    fields
    |> discard_droppable_fields(params)
    |> Enum.reduce(default, fn
      {:embed_one, name, block}, acc ->
        acc
        |> put_in([:data, name], nil)
        |> put_in([:embeds, name], {:embed_one, block})
        |> put_in([:types, name], {:map, :string})

      {:embed_many, name, block}, acc ->
        acc
        |> put_in([:data, name], nil)
        |> put_in([:embeds, name], {:embed_many, block})
        |> put_in([:types, name], {:map, :string})

      {requirement, name, type, opts}, acc ->
        acc
        |> put_in([:data, name], opts[:default])
        |> put_in([:types, name], type)
        |> assign_permitted_fields(name)
        |> assign_required_fields(requirement, name)
        |> assign_inline_validators(name, opts)

      _, acc ->
        acc
    end)
  end

  @doc false
  def discard_droppable_fields(fields, params) do
    Enum.filter(fields, fn
      # optional/required fields
      {_, name, _, opts} ->
        with true <- opts[:droppable],
             false <- Map.has_key?(params, Atom.to_string(name)) do
          false
        else
          _ -> true
        end

      # embed fields
      {_, name, opts} ->
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
  def assign_permitted_fields(spec, name) do
    put_in(spec, [:permitted], spec.permitted ++ [name])
  end

  @doc false
  def assign_required_fields(spec, :required, name) do
    put_in(spec, [:required], spec.required ++ [name])
  end

  def assign_required_fields(spec, _, _), do: spec

  @doc false
  def assign_inline_validators(spec, name, opts) do
    if validator = opts[:validator] do
      put_in(spec, [:validators, name], validator)
    else
      spec
    end
  end

  @doc false
  def validate_embeds(changeset, module, %{embeds: embeds}) do
    Enum.reduce(embeds, changeset, fn {name, embed}, acc ->
      validate_embed(acc, module, name, embed, changeset.params)
    end)
  end

  def validate_embeds(changeset, _, _), do: changeset

  @doc false
  def validate_embed(changeset, module, name, {:embed_one, block}, params) do
    params = Map.get(params, Atom.to_string(name))

    case do_validate(module, block, params) do
      %{valid?: true} = valid_changeset ->
        Ecto.Changeset.put_change(changeset, name, valid_changeset)

      invalid_changeset ->
        Ecto.Changeset.put_change(%{changeset | valid?: false}, name, invalid_changeset)
    end
  end

  def validate_embed(changeset, module, name, {:embed_many, block}, params) do
    params = Map.get(params, Atom.to_string(name))

    if is_list(params) do
      Enum.reduce(params, changeset, fn embedded_params, acc ->
        embedded_changesets = Ecto.Changeset.get_change(acc, name, [])

        case do_validate(module, block, embedded_params) do
          %{valid?: true} = valid_changeset ->
            Ecto.Changeset.put_change(
              acc,
              name,
              embedded_changesets ++ [valid_changeset]
            )

          invalid_changeset ->
            Ecto.Changeset.put_change(
              %{acc | valid?: false},
              name,
              embedded_changesets ++ [invalid_changeset]
            )
        end
      end)
    else
      changeset
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

      function when is_atom(function) ->
        do_apply_inline_validator(module, function, [changeset, key, []])

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

  @doc false
  def apply_changes(%{changes: changes, data: data}) do
    Enum.reduce(changes, data, fn
      {key, list}, acc when is_list(list) ->
        Map.put(acc, key, apply_changes(list))

      {key, %Ecto.Changeset{} = changeset}, acc ->
        Map.put(acc, key, apply_changes(changeset))

      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  def apply_changes(list) when is_list(list) do
    Enum.map(list, &apply_changes/1)
  end

  def apply_changes(any), do: any
end
