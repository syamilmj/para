defmodule ParaTest do
  use ExUnit.Case

  doctest Para

  defmodule ProductPara do
    use Para

    validator :create do
      required :name
      required :price, :float
      optional :category, :string, validator: {:validate_inclusion, ["mobile", "laptop"]}
    end
  end

  test "it validates required fields" do
    assert {:error, %{valid?: false}} = ProductPara.validate(:create, %{})
  end

  test "it validates using defined validator" do
    params = %{"name" => "iPod", "price" => "20.00"}
    assert {:ok, %{name: "iPod", price: 20.0}} = ProductPara.validate(:create, params)
  end

  test "it validates using inline validator" do
    params = %{"name" => "iPod", "price" => "20.00", "category" => "desktop"}

    assert {:error, %{errors: [category: {"is invalid", _}]}} =
             ProductPara.validate(:create, params)
  end

  defmodule AnimalPara do
    use Para

    validator :create do
      required :name
      required :origin, :string, droppable: true
    end
  end

  test "it discards droppable fields" do
    params = %{"name" => "Cheetah"}
    assert {:ok, %{name: "Cheetah"}} = AnimalPara.validate(:create, params)
  end

  test "it rejects empty value for droppable fields" do
    params = %{"name" => "Cheetah", "origin" => ""}

    assert {:error, %{errors: [origin: {"can't be blank", _}]}} =
             AnimalPara.validate(:create, params)
  end

  defmodule VehiclePara do
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
             VehiclePara.validate(:create, params)
  end

  defmodule EmbedsOnePara do
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
             EmbedsOnePara.validate(:test, params)
  end

  test "it validates embeds_one with atom keys" do
    params = %{title: "test", product: %{name: "TEST", price: "10.00"}}

    assert {:ok, %{title: "test", product: %{name: "TEST", price: 10.0}}} =
             EmbedsOnePara.validate(:test, params)
  end

  test "it rejects invalid embeds_one params" do
    params = %{"title" => "test", "product" => %{"price" => "10.00"}}

    assert {:error, %{changes: %{product: %{errors: [name: {"can't be blank", _}]}}}} =
             EmbedsOnePara.validate(:test, params)
  end

  defmodule EmbedsManyPara do
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
            }} = EmbedsManyPara.validate(:test, params)
  end

  test "it validates empty embeds_many params" do
    params = %{"title" => "test", "products" => nil}
    assert {:ok, %{title: "test", products: nil}} = EmbedsManyPara.validate(:test, params)
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
             EmbedsManyPara.validate(:test, invalid_params)
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

  defmodule ArrayMapPara do
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

    assert {:ok, %{map: ^map, list: ^list, data: ^data}} = ArrayMapPara.validate(:test, params)
  end
end
