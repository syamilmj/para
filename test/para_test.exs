defmodule ParaTest do
  use ExUnit.Case

  doctest Para

  defmodule ProductParams do
    use Para

    validator :create do
      required :name
      required :price, :float

      optional :vendor, :string,
        validator: {:validate_inclusion, ["apple", "lenovo"], message: "is not registered"}

      optional :category, :string, validator: {:validate_inclusion, ["mobile", "laptop"]}
    end
  end

  test "it validates required fields" do
    assert {:error, %{valid?: false}} = ProductParams.validate(:create, %{})
  end

  test "it validates using defined validator" do
    params = %{"name" => "iPod", "price" => "20.00"}
    assert {:ok, %{name: "iPod", price: 20.0}} = ProductParams.validate(:create, params)
  end

  test "it validates using inline validator" do
    params = %{"name" => "iPod", "price" => "20.00", "category" => "desktop"}

    assert {:error, %{errors: [category: {"is invalid", _}]}} =
             ProductParams.validate(:create, params)
  end

  test "it returns custom error message" do
    params = %{vendor: "dell"}

    {:error, %{errors: errors}} = ProductParams.validate(:create, params)
    error = Enum.find(errors, &(elem(&1, 0) == :vendor))

    assert {:vendor, {"is not registered", _}} = error
  end

  defmodule AnimalParams do
    use Para

    validator :create do
      required :name
      required :origin, :string, droppable: true
    end
  end

  test "it discards droppable fields" do
    params = %{"name" => "Cheetah"}
    assert {:ok, %{name: "Cheetah"}} = AnimalParams.validate(:create, params)
  end

  test "it rejects empty value for droppable fields" do
    params = %{"name" => "Cheetah", "origin" => ""}

    assert {:error, %{errors: [origin: {"can't be blank", _}]}} =
             AnimalParams.validate(:create, params)
  end

  defmodule VehicleParams do
    use Para
    import Ecto.Changeset

    validator :create do
      required :brand
      required :fuel_source
      callback :validate_eco_friendliness
    end

    def validate_eco_friendliness(changeset, _params) do
      case get_change(changeset, :fuel_source) do
        fuel_source when fuel_source not in ["solar", "water", "wind"] ->
          add_error(changeset, :fuel_source, "is not eco-friendly")

        _ ->
          changeset
      end
    end
  end

  test "it uses defined callback" do
    params = %{"brand" => "Tesla", "fuel_source" => "coal"}

    assert {:error, %{errors: [fuel_source: {"is not eco-friendly", _}]}} =
             VehicleParams.validate(:create, params)
  end

  defmodule EmbedsOneParams do
    use Para

    validator :test do
      required :title, :string

      embeds_one :product do
        required :name
        required :price, :float
      end
    end
  end

  test "it validates embeds_one" do
    params = %{"title" => "test", "product" => %{"name" => "TEST", "price" => "10.00"}}

    assert {:ok, %{title: "test", product: %{name: "TEST", price: 10.0}}} =
             EmbedsOneParams.validate(:test, params)
  end

  test "it validates embeds_one with atom keys" do
    params = %{title: "test", product: %{name: "TEST", price: "10.00"}}

    assert {:ok, %{title: "test", product: %{name: "TEST", price: 10.0}}} =
             EmbedsOneParams.validate(:test, params)
  end

  test "it rejects invalid embeds_one params" do
    params = %{"title" => "test", "product" => %{"price" => "10.00"}}

    assert {:error, %{changes: %{product: %{errors: [name: {"can't be blank", _}]}}}} =
             EmbedsOneParams.validate(:test, params)
  end

  test "it skips validation when embeds_one key is missing" do
    params = %{"title" => "test"}
    assert {:ok, %{title: "test", product: nil}} = EmbedsOneParams.validate(:test, params)
  end

  test "it skips validation when embeds_one params are nil" do
    params = %{"title" => "test", "product" => nil}
    assert {:ok, %{title: "test", product: nil}} = EmbedsOneParams.validate(:test, params)
  end

  defmodule EmbedsManyParams do
    use Para

    validator :test do
      required :title, :string

      embeds_many :products do
        required :name
        required :price, :float
      end
    end
  end

  test "it validates embeds_many" do
    params = %{
      "title" => "test",
      "products" => [
        %{"name" => "TEST1", "price" => "10.00"},
        %{"name" => "TEST2", "price" => "20.00"}
      ]
    }

    assert {:ok,
            %{
              title: "test",
              products: [%{name: "TEST1", price: 10.0}, %{name: "TEST2", price: 20.0}]
            }} = EmbedsManyParams.validate(:test, params)
  end

  test "it validates empty embeds_many params" do
    params = %{"title" => "test", "products" => nil}
    assert {:ok, %{title: "test", products: nil}} = EmbedsManyParams.validate(:test, params)
  end

  test "it rejects invalid embeds_many params" do
    invalid_params = %{
      "title" => "test",
      "products" => [
        %{"name" => "TEST1", "price" => "10.00"},
        %{"name" => "TEST2", "price" => "string"}
      ]
    }

    assert {:error, %{changes: %{products: [_, %{valid?: false}]}}} =
             EmbedsManyParams.validate(:test, invalid_params)
  end

  defmodule EmbedsManyWithCallback do
    use Para
    import Ecto.Changeset

    validator :test do
      embeds_many :children do
        required :first_name
        required :last_name
        optional :full_name
        callback :assign_full_name
      end
    end

    def assign_full_name(changeset, _params) do
      with nil <- get_change(changeset, :full_name),
           first_name when is_binary(first_name) <- get_change(changeset, :first_name),
           last_name when is_binary(last_name) <- get_change(changeset, :last_name) do
        put_change(changeset, :full_name, "#{first_name} #{last_name}")
      else
        _ -> changeset
      end
    end
  end

  test "it runs embedded callback" do
    params = %{
      children: [
        %{first_name: "Eli", last_name: "Ji"},
        %{first_name: "Fang", last_name: "Xe Yi", full_name: "Fang XY"}
      ]
    }

    assert {:ok, %{children: [%{full_name: "Eli Ji"}, %{full_name: "Fang XY"}]}} =
             EmbedsManyWithCallback.validate(:test, params)
  end

  defmodule ArrayMapParams do
    use Para

    validator :test do
      required :map, :map
      required :list, {:array, :string}
      required :data, {:array, :map}
    end
  end

  test "it validates embedded map or arrays and returns original data" do
    map = %{"foo" => "bar"}
    list = ["one", "two"]
    data = [%{"foo" => "bar"}, %{"baz" => "qux"}]
    params = %{"map" => map, "list" => list, "data" => data}

    assert {:ok, %{map: ^map, list: ^list, data: ^data}} = ArrayMapParams.validate(:test, params)
  end

  defmodule CustomInlineValidatorParams do
    use Para
    import Ecto.Changeset

    validator :test do
      required :url, :string, validator: :validate_url
      required :another_url, :string, validator: {:validate_url, [host: "example.com"]}
    end

    def validate_url(changeset, key, opts) do
      with {:ok, url} <- fetch_change(changeset, key),
           {:url, true} <- {:url, url =~ ~r/http(s?)/i},
           {:host, true} <- {:host, valid_host?(url, opts[:host])} do
        changeset
      else
        :error -> changeset
        {:url, _} -> add_error(changeset, key, "invalid URL")
        {:host, _} -> add_error(changeset, key, "invalid host")
      end
    end

    def valid_host?(_url, nil), do: true

    def valid_host?(url, host) do
      case URI.parse(url) do
        %{host: ^host} -> true
        _ -> false
      end
    end
  end

  describe "with custom inline validator" do
    test "it validates correct params" do
      params = %{url: "http://example.com", another_url: "https://example.com/1234"}
      result = CustomInlineValidatorParams.validate(:test, params)

      assert {:ok, ^params} = result
    end

    test "it validates incorrect params" do
      params = %{url: "ftp://example.com", another_url: "https://example.net/1234"}

      assert {:error, changeset} = CustomInlineValidatorParams.validate(:test, params)
      assert "invalid URL" in errors_on(changeset).url
      assert "invalid host" in errors_on(changeset).another_url
    end
  end

  defmodule SpecParams do
    use Para

    validator :test do
      required :title, :string

      embeds_one :product do
        required :name
        required :price, :float
      end
    end
  end

  test "it builds spec for changeset" do
    spec = SpecParams.spec(:test, %{})

    assert %{
             data: %{product: nil, title: nil},
             embeds: %{
               product:
                 {:embed_one, [{:required, :name, :string, []}, {:required, :price, :float, []}]}
             },
             permitted: [:title],
             required: [:title],
             types: %{product: {:map, :string}, title: :string},
             validators: %{}
           } = spec

    assert %Ecto.Changeset{} = Ecto.Changeset.change({spec.data, spec.types}, %{})
  end

  defmodule CustomType do
    use Ecto.Type

    def type, do: :map
    def cast(data), do: {:ok, data}
    def load(data), do: {:ok, data}
    def dump(data), do: {:ok, data}
  end

  defmodule CustomTypeParams do
    use Para

    validator :test do
      required :status, Ecto.Enum, values: [:active, :inactive]
      required :data, CustomType
    end
  end

  test "it validates custom Ecto.Type and Ecto.ParameterizedType fields" do
    params = %{status: :active, data: %{"foo" => "bar"}}
    result = CustomTypeParams.validate(:test, params)

    assert {:ok, ^params} = result
  end

  defmodule DroppableEmbedsParams do
    use Para

    validator :update do
      required :name, :string

      embeds_one :address, droppable: true do
        required :street, :string
        required :city, :string
      end

      embeds_many :tags, droppable: true do
        required :label, :string
      end
    end
  end

  describe "droppable embeds_one" do
    test "drops the embed when the key is missing" do
      params = %{"name" => "Alice"}
      assert {:ok, result} = DroppableEmbedsParams.validate(:update, params)
      assert result == %{name: "Alice"}
    end

    test "validates the embed when the key is present" do
      params = %{
        "name" => "Alice",
        "address" => %{"street" => "1 Main", "city" => "Springfield"}
      }

      assert {:ok, %{name: "Alice", address: %{street: "1 Main", city: "Springfield"}}} =
               DroppableEmbedsParams.validate(:update, params)
    end

    test "rejects the embed when its required fields are missing" do
      params = %{"name" => "Alice", "address" => %{"street" => "1 Main"}}

      assert {:error, %{changes: %{address: %{errors: [city: {"can't be blank", _}]}}}} =
               DroppableEmbedsParams.validate(:update, params)
    end
  end

  describe "droppable embeds_many" do
    test "drops the embed when the key is missing" do
      params = %{"name" => "Alice"}
      assert {:ok, result} = DroppableEmbedsParams.validate(:update, params)
      refute Map.has_key?(result, :tags)
    end

    test "validates the embed when the key is present" do
      params = %{"name" => "Alice", "tags" => [%{"label" => "vip"}, %{"label" => "beta"}]}

      assert {:ok, %{name: "Alice", tags: [%{label: "vip"}, %{label: "beta"}]}} =
               DroppableEmbedsParams.validate(:update, params)
    end
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
