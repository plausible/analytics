defmodule Plausible.Billing.PaddleApiTest do
  use Plausible.DataCase

  import Mox
  setup :verify_on_exit!

  @success Jason.decode!(
             ~s/{"response":{"customer_country":"ES","products":[{"currency":"EUR","list_price":{"gross":7.26,"net":6.0,"tax":1.26},"price":{"gross":7.26,"net":6.0,"tax":1.26},"product_id":19878,"product_title":"kymme tuhat","subscription":{"frequency":1,"interval":"month","list_price":{"gross":7.26,"net":6.0,"tax":1.26},"price":{"gross":7.26,"net":6.0,"tax":1.26},"trial_days":0},"vendor_set_prices_included_tax":false},{"currency":"EUR","list_price":{"gross":72.6,"net":60.0,"tax":12.6},"price":{"gross":72.6,"net":60.0,"tax":12.6},"product_id":20127,"product_title":"kymme tuhat yearly","subscription":{"frequency":1,"interval":"year","list_price":{"gross":72.6,"net":60.0,"tax":12.6},"price":{"gross":72.6,"net":60.0,"tax":12.6},"trial_days":0},"vendor_set_prices_included_tax":false},{"currency":"EUR","list_price":{"gross":14.93,"net":12.34,"tax":2.59},"price":{"gross":14.93,"net":12.34,"tax":2.59},"product_id":20657,"product_title":"sadat tuhat","subscription":{"frequency":1,"interval":"month","list_price":{"gross":14.93,"net":12.34,"tax":2.59},"price":{"gross":14.93,"net":12.34,"tax":2.59},"trial_days":0},"vendor_set_prices_included_tax":false},{"currency":"EUR","list_price":{"gross":145.61,"net":120.34,"tax":25.27},"price":{"gross":145.61,"net":120.34,"tax":25.27},"product_id":20658,"product_title":"sada tuhat yearly","subscription":{"frequency":1,"interval":"year","list_price":{"gross":145.61,"net":120.34,"tax":25.27},"price":{"gross":145.61,"net":120.34,"tax":25.27},"trial_days":0},"vendor_set_prices_included_tax":false}]},"success":true}/
           )

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

      assert Plausible.Billing.PaddleApi.fetch_prices(["19878", "20127", "20657", "20658"]) ==
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
