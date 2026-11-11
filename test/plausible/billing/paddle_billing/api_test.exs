defmodule Plausible.Billing.PaddleBilling.ApiTest do
  use Plausible.DataCase

  import Mox
  alias Plausible.Billing.PaddleBilling.Api
  alias Plausible.HTTPClient.Non200Error

  setup :verify_on_exit!

  @product_id "pro_01h1vjes1y163xfj1rh1tkfb65"
  @price_id "pri_01gsz8z1q1n00f12qt7fgvhfkv"

  describe "create_price/3" do
    test "posts a monthly standard price to the sandbox API" do
      expect(Plausible.HTTPClient.Mock, :post, fn url, headers, params ->
        assert url == "https://sandbox-api.paddle.com/prices"
        assert {"authorization", "Bearer test_api_key"} in headers
        assert {"content-type", "application/json"} in headers

        assert json_map(params) == %{
                 "product_id" => @product_id,
                 "type" => "standard",
                 "description" => "10k pageviews, monthly",
                 "unit_price" => %{"amount" => "900", "currency_code" => "USD"},
                 "unit_price_overrides" => [],
                 "billing_cycle" => %{"interval" => "month", "frequency" => 1},
                 "quantity" => %{"minimum" => 1, "maximum" => 1},
                 "tax_mode" => "account_setting",
                 "custom_data" => %{}
               }

        {:ok, created(%{"id" => @price_id})}
      end)

      assert {:ok, %{"id" => @price_id}} =
               Api.create_price(@product_id, "10k pageviews, monthly",
                 price: Money.new(:USD, "9"),
                 interval: :monthly
               )
    end

    test "uses the year interval for yearly prices" do
      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, params ->
        assert json_map(params)["billing_cycle"] == %{"interval" => "year", "frequency" => 1}
        {:ok, created(%{})}
      end)

      assert {:ok, _} =
               Api.create_price(@product_id, "yearly",
                 price: Money.new(:USD, "90"),
                 interval: :yearly
               )
    end

    test "sends amounts in the lowest denomination, 10 USD is 1000" do
      expect(Plausible.HTTPClient.Mock, :post, 2, fn _url, _headers, params ->
        send(self(), {:amount, json_map(params)["unit_price"]["amount"]})
        {:ok, created(%{})}
      end)

      Api.create_price(@product_id, "a", price: Money.new(:USD, "10"), interval: :monthly)
      Api.create_price(@product_id, "b", price: Money.new(:USD, "9.5"), interval: :monthly)

      assert_received {:amount, "1000"}
      assert_received {:amount, "950"}
    end

    test "creates custom prices when explicitly instructed" do
      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, params ->
        assert json_map(params)["type"] == "custom"
        {:ok, created(%{})}
      end)

      assert {:ok, _} =
               Api.create_price(@product_id, "enterprise",
                 price: Money.new(:USD, "319"),
                 interval: :monthly,
                 type: :custom
               )
    end

    test "adds parity overrides for the eurozone and the UK with the same number" do
      eurozone = ~w(AT BE BG HR CY EE FI FR DE GR IE IT LV LT LU MT NL PT SK SI ES)

      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, params ->
        assert json_map(params)["unit_price_overrides"] == [
                 %{
                   "country_codes" => eurozone,
                   "unit_price" => %{"amount" => "900", "currency_code" => "EUR"}
                 },
                 %{
                   "country_codes" => ["GB"],
                   "unit_price" => %{"amount" => "900", "currency_code" => "GBP"}
                 }
               ]

        {:ok, created(%{})}
      end)

      assert {:ok, _} =
               Api.create_price(@product_id, "with overrides",
                 price: Money.new(:USD, "9"),
                 interval: :monthly,
                 overrides?: true
               )
    end

    test "refuses to build parity overrides on a base price that isn't USD" do
      assert_raise MatchError, fn ->
        Api.create_price(@product_id, "eur base",
          price: Money.new(:EUR, "9"),
          interval: :monthly,
          overrides?: true
        )
      end
    end

    test "passes the tax mode through, internal means tax-inclusive" do
      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, params ->
        assert json_map(params)["tax_mode"] == "internal"
        {:ok, created(%{})}
      end)

      assert {:ok, _} =
               Api.create_price(@product_id, "v1",
                 price: Money.new(:USD, "48"),
                 interval: :yearly,
                 tax_mode: :internal
               )
    end

    test "attaches custom data, for example the Classic plan id" do
      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, params ->
        assert json_map(params)["custom_data"] == %{"classic_plan_id" => "597643"}
        {:ok, created(%{})}
      end)

      assert {:ok, _} =
               Api.create_price(@product_id, "with data",
                 price: Money.new(:USD, "384"),
                 interval: :yearly,
                 custom_data: %{classic_plan_id: "597643"}
               )
    end

    test "returns Paddle's error body for a rejected request" do
      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, _params ->
        {:error, non_200(400, %{"error" => %{"code" => "invalid_field", "detail" => "bad"}})}
      end)

      assert {:error, %{"code" => "invalid_field"}} =
               Api.create_price(@product_id, "x", price: Money.new(:USD, "9"), interval: :monthly)
    end

    test "returns transport errors untouched" do
      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, _params ->
        {:error, %Mint.TransportError{reason: :timeout}}
      end)

      assert {:error, %Mint.TransportError{reason: :timeout}} =
               Api.create_price(@product_id, "x", price: Money.new(:USD, "9"), interval: :monthly)
    end
  end

  describe "update_price/2" do
    test "patches only the given fields" do
      expect(Plausible.HTTPClient.Mock, :patch, fn url, headers, params ->
        assert url == "https://sandbox-api.paddle.com/prices/#{@price_id}"
        assert {"authorization", "Bearer test_api_key"} in headers
        assert json_map(params) == %{"status" => "archived", "description" => "old"}
        {:ok, ok(%{"id" => @price_id})}
      end)

      assert {:ok, %{"id" => @price_id}} =
               Api.update_price(@price_id, status: "archived", description: "old")
    end

    test "updates the unit price in the lowest denomination" do
      expect(Plausible.HTTPClient.Mock, :patch, fn _url, _headers, params ->
        assert json_map(params) == %{
                 "unit_price" => %{"amount" => "1200", "currency_code" => "USD"}
               }

        {:ok, ok(%{})}
      end)

      assert {:ok, _} = Api.update_price(@price_id, price: Money.new(:USD, "12"))
    end

    test "updates parity overrides along with the price" do
      expect(Plausible.HTTPClient.Mock, :patch, fn _url, _headers, params ->
        json_map = json_map(params)
        assert json_map["unit_price"] == %{"amount" => "1200", "currency_code" => "USD"}

        assert [%{"unit_price" => %{"amount" => "1200", "currency_code" => "EUR"}}, gb] =
                 json_map["unit_price_overrides"]

        assert gb == %{
                 "country_codes" => ["GB"],
                 "unit_price" => %{"amount" => "1200", "currency_code" => "GBP"}
               }

        {:ok, ok(%{})}
      end)

      assert {:ok, _} =
               Api.update_price(@price_id, price: Money.new(:USD, "12"), overrides?: true)
    end

    test "refuses to update overrides without the price they derive from" do
      assert_raise KeyError, fn -> Api.update_price(@price_id, overrides?: true) end
    end

    test "changes the tax mode and custom data" do
      expect(Plausible.HTTPClient.Mock, :patch, fn _url, _headers, params ->
        assert json_map(params) == %{"tax_mode" => "external", "custom_data" => %{"a" => "b"}}
        {:ok, ok(%{})}
      end)

      assert {:ok, _} = Api.update_price(@price_id, tax_mode: :external, custom_data: %{a: "b"})
    end

    test "makes no request when there is nothing to change" do
      assert {:error, :no_changes} = Api.update_price(@price_id)
      assert {:error, :no_changes} = Api.update_price(@price_id, unknown: "ignored")
    end

    test "returns Paddle's error body for a rejected request" do
      expect(Plausible.HTTPClient.Mock, :patch, fn _url, _headers, _params ->
        {:error, non_200(404, %{"error" => %{"code" => "not_found"}})}
      end)

      assert {:error, %{"code" => "not_found"}} = Api.update_price(@price_id, status: "archived")
    end
  end

  describe "create_product/3" do
    test "posts a standard saas product" do
      expect(Plausible.HTTPClient.Mock, :post, fn url, headers, params ->
        assert url == "https://sandbox-api.paddle.com/products"
        assert {"authorization", "Bearer test_api_key"} in headers

        assert json_map(params) == %{
                 "name" => "Plausible Growth",
                 "description" => nil,
                 "type" => "standard",
                 "tax_category" => "saas",
                 "custom_data" => %{"tier" => "growth"}
               }

        {:ok, created(%{"id" => @product_id})}
      end)

      assert {:ok, %{"id" => @product_id}} =
               Api.create_product("Plausible Growth", %{tier: "growth"})
    end

    test "creates a product with a description for enterprise" do
      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, params ->
        json_map = json_map(params)
        assert json_map["type"] == "standard"
        assert json_map["description"] == "Enterprise deal"
        assert json_map["custom_data"]["enterprise"] == true
        {:ok, created(%{})}
      end)

      assert {:ok, _} =
               Api.create_product("Enterprise", %{},
                 enterprise?: true,
                 description: "Enterprise deal"
               )
    end

    test "returns Paddle's error body for a rejected request" do
      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, _params ->
        {:error, non_200(400, %{"error" => %{"code" => "invalid_field"}})}
      end)

      assert {:error, %{"code" => "invalid_field"}} = Api.create_product("x", %{})
    end
  end

  describe "update_product/2" do
    test "patches only the given fields" do
      expect(Plausible.HTTPClient.Mock, :patch, fn url, _headers, params ->
        assert url == "https://sandbox-api.paddle.com/products/#{@product_id}"
        assert json_map(params) == %{"name" => "Renamed", "status" => "archived"}
        {:ok, ok(%{"id" => @product_id})}
      end)

      assert {:ok, %{"id" => @product_id}} =
               Api.update_product(@product_id, name: "Renamed", status: "archived")
    end

    test "makes no request when there is nothing to change" do
      assert {:error, :no_changes} = Api.update_product(@product_id)
    end

    test "returns Paddle's error body for a rejected request" do
      expect(Plausible.HTTPClient.Mock, :patch, fn _url, _headers, _params ->
        {:error, non_200(404, %{"error" => %{"code" => "not_found"}})}
      end)

      assert {:error, %{"code" => "not_found"}} = Api.update_product(@product_id, name: "x")
    end
  end

  describe "list_products/0" do
    test "requests the maximum page size with prices included across standard and custom products" do
      expect(Plausible.HTTPClient.Mock, :get, 2, fn url, headers ->
        assert %URI{host: "sandbox-api.paddle.com", path: "/products"} = URI.parse(url)

        query_params = URI.decode_query(URI.parse(url).query)

        assert map_size(query_params) == 3

        assert %{
                 "per_page" => "200",
                 "include" => "prices",
                 "type" => type
               } = query_params

        assert type in ["custom", "standard"]

        prod_id = if(type == "standard", do: "pro_1", else: "pro_2")

        assert {"authorization", "Bearer test_api_key"} in headers

        {:ok, ok([%{"id" => prod_id}], %{"pagination" => %{"has_more" => false}})}
      end)

      assert {:ok, [%{"id" => "pro_1"}, %{"id" => "pro_2"}]} = Api.list_products()
    end

    test "follows the next page url until there are no more" do
      next = "https://sandbox-api.paddle.com/products?after=pro_2&per_page=200&include=prices"

      expect(Plausible.HTTPClient.Mock, :get, 3, fn
        ^next, _headers ->
          {:ok, ok([%{"id" => "pro_3"}], %{"pagination" => %{"has_more" => false}})}

        first, _headers ->
          query_params = URI.decode_query(URI.parse(first).query)

          {products, has_more?, next} =
            if query_params["type"] == "standard" do
              {[%{"id" => "pro_1"}, %{"id" => "pro_2"}], true, next}
            else
              {[], false, nil}
            end

          {:ok,
           ok(products, %{
             "pagination" => %{"has_more" => has_more?, "next" => next}
           })}
      end)

      assert {:ok, [%{"id" => "pro_1"}, %{"id" => "pro_2"}, %{"id" => "pro_3"}]} =
               Api.list_products()
    end

    test "returns Paddle's error body for a rejected request" do
      expect(Plausible.HTTPClient.Mock, :get, fn _url, _headers ->
        {:error, non_200(403, %{"error" => %{"code" => "forbidden"}})}
      end)

      assert {:error, %{"code" => "forbidden"}} = Api.list_products()
    end

    test "returns an error from a later page" do
      next = "https://sandbox-api.paddle.com/products?after=pro_1"

      expect(Plausible.HTTPClient.Mock, :get, 2, fn
        ^next, _headers ->
          {:error, non_200(500, %{"error" => %{"code" => "internal_error"}})}

        _first, _headers ->
          {:ok,
           ok([%{"id" => "pro_1"}], %{"pagination" => %{"has_more" => true, "next" => next}})}
      end)

      assert {:error, %{"code" => "internal_error"}} = Api.list_products()
    end
  end

  describe "api_domain/0" do
    test "points at the sandbox outside of production" do
      assert Api.api_domain() == "https://sandbox-api.paddle.com"
    end
  end

  # :USD => "USD" etc.
  defp json_map(params), do: params |> Jason.encode!() |> Jason.decode!()

  defp ok(data, meta \\ %{}) do
    %Finch.Response{
      status: 200,
      headers: [{"content-type", "application/json"}],
      body: %{"data" => data, "meta" => meta}
    }
  end

  defp created(data), do: %{ok(data) | status: 201}

  defp non_200(status, body) do
    Non200Error.new(%Finch.Response{
      status: status,
      headers: [{"content-type", "application/json"}],
      body: body
    })
  end
end
