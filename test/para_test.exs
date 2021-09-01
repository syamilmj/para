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
    assert ProductPara.validate(:create, %{})
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
end
