defmodule Plausible.Billing.PaddleApiTest do
  use Plausible.DataCase

  import Mox
  setup :verify_on_exit!

  @success "fixture/paddle_prices_success_response.json" |> File.read!() |> Jason.decode!()

  describe "fetch_prices/1" do
    test "returns %Money{} structs per product_id when given a list of product_ids" do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn "https://checkout.paddle.com/api/2.0/prices",
           [{"content-type", "application/json"}, {"accept", "application/json"}],
           %{product_ids: "19878,20127,20657,20658"} ->
          {:ok,
           %Finch.Response{
             status: 200,
             headers: [{"content-type", "application/json"}],
             body: @success
           }}
        end
      )

      assert Plausible.Billing.PaddleApi.fetch_prices(
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
end
