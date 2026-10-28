defmodule Plausible.Billing.PaddleClassic.ApiTest do
  use Plausible.DataCase

  import Mox
  alias Plausible.Billing.PaddleClassic.Api
  setup :verify_on_exit!

  @success "fixture/paddle_prices_success_response.json" |> File.read!() |> Jason.decode!()

  describe "fetch_prices/1" do
    test "returns %Money{} structs per product_id when given a list of product_ids" do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn "https://checkout.paddle.com/api/2.0/prices" <> query,
           [{"content-type", "application/json"}, {"accept", "application/json"}],
           _ ->
          assert query =~ "product_ids=#{URI.encode_www_form("19878,20127,20657,20658")}"

          {:ok,
           %Finch.Response{
             status: 200,
             headers: [{"content-type", "application/json"}],
             body: @success
           }}
        end
      )

      assert Api.fetch_prices(
               ["19878", "20127", "20657", "20658"],
               "127.0.0.1"
             ) ==
               {:ok,
                %{
                  "19878" => Money.new(:EUR, "6.0"),
                  "20127" => Money.new(:EUR, "60.0"),
                  "20657" => Money.new(:EUR, "12.34"),
                  "20658" => Money.new(:EUR, "120.34")
                }}
    end
  end

  describe "list_plans/0" do
    test "follows pagination until all plans are fetched" do
      expect(Plausible.HTTPClient.Mock, :post, 2, fn
        "https://vendors.paddle.com/api/2.0/subscription/plans",
        _headers,
        %{offset: 0} = params ->
          assert params.limit == 500

          {:ok,
           ok_response(%{
             "success" => true,
             "count" => 2,
             "total" => 3,
             "response" => [%{"id" => 1}, %{"id" => 2}]
           })}

        "https://vendors.paddle.com/api/2.0/subscription/plans", _headers, %{offset: 2} ->
          {:ok,
           ok_response(%{
             "success" => true,
             "count" => 1,
             "total" => 3,
             "response" => [%{"id" => 3}]
           })}
      end)

      assert {:ok, [%{"id" => 1}, %{"id" => 2}, %{"id" => 3}]} =
               Api.list_plans()
    end

    test "stops on an empty page instead of looping" do
      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, _params ->
        {:ok, ok_response(%{"success" => true, "count" => 0, "total" => 5, "response" => []})}
      end)

      assert {:ok, []} = Api.list_plans()
    end

    test "returns Paddle's error" do
      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, _params ->
        {:ok,
         ok_response(%{"success" => false, "error" => %{"code" => 100, "message" => "bad auth"}})}
      end)

      assert {:error, %{"code" => 100}} = Api.list_plans()
    end

    test "returns transport errors" do
      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, _params ->
        {:error, %Mint.TransportError{reason: :timeout}}
      end)

      assert {:error, :timeout} = Api.list_plans()
    end
  end

  describe "list_modifiers/0 pagination" do
    test "pages with `after` until a page is short" do
      full_page = for id <- 1..250, do: %{"modifier_id" => id}

      expect(Plausible.HTTPClient.Mock, :post, 2, fn
        _url, _headers, %{results_per_page: 250} = params when not is_map_key(params, :after) ->
          {:ok, ok_response(%{"success" => true, "response" => full_page})}

        _url, _headers, %{results_per_page: 250, after: 250} ->
          {:ok, ok_response(%{"success" => true, "response" => [%{"modifier_id" => 251}]})}
      end)

      assert {:ok, modifiers} = Api.list_modifiers()
      assert length(modifiers) == 251
      assert List.last(modifiers) == %{"modifier_id" => 251}
    end

    test "never counts a modifier twice if `after` turns out to be inclusive" do
      full_page = for id <- 1..250, do: %{"modifier_id" => id}

      expect(Plausible.HTTPClient.Mock, :post, 2, fn
        _url, _headers, %{results_per_page: 250} = params when not is_map_key(params, :after) ->
          {:ok, ok_response(%{"success" => true, "response" => full_page})}

        _url, _headers, %{after: 250} ->
          # the last modifier of the previous page comes back first
          {:ok, ok_response(%{"success" => true, "response" => [%{"modifier_id" => 250}]})}
      end)

      assert {:ok, modifiers} = Api.list_modifiers()
      assert length(modifiers) == 250
    end
  end

  describe "list_modifiers/0" do
    test "lists the modifiers" do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn "https://vendors.paddle.com/api/2.0/subscription/modifiers", _headers, params ->
          refute Map.has_key?(params, :subscription_id)
          {:ok, ok_response(%{"success" => true, "response" => [%{"modifier_id" => 1}]})}
        end
      )

      assert {:ok, [%{"modifier_id" => 1}]} = Api.list_modifiers()
    end

    test "returns Paddle's error" do
      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, _params ->
        {:ok, ok_response(%{"success" => false, "error" => "nope"})}
      end)

      assert {:error, "nope"} = Api.list_modifiers()
    end
  end

  defp ok_response(body) do
    %Finch.Response{status: 200, headers: [{"content-type", "application/json"}], body: body}
  end
end
