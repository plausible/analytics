defmodule Plausible.Billing.PaddleBilling.MigrationTest do
  use Plausible.DataCase

  import Mox

  alias Plausible.Billing.PaddleBilling.Migration

  setup :verify_on_exit!

  describe "sync_enterprise" do
    test "it works" do
      team = new_site().team

      insert(:enterprise_plan,
        team: team,
        paddle_plan_id: "123"
      )

      stub(Plausible.HTTPClient.Mock, :post, fn
        "https://vendors.paddle.com/api/2.0/subscription/plans", _headers, _params ->
          {:ok,
           ok_response(%{
             "success" => true,
             "count" => 1,
             "total" => 1,
             "response" => [%{"id" => 123, "recurring_price" => %{"USD" => "9.000"}}]
           })}

        "https://sandbox-api.paddle.com/products", _headers, _params ->
          {:ok,
           ok_response(
             %{
               "data" => %{
                 "id" => "prod_123"
               }
             },
             201
           )}

        "https://sandbox-api.paddle.com/prices", _headers, _params ->
          {:ok,
           ok_response(
             %{
               "data" => %{
                 "id" => "price_456"
               }
             },
             201
           )}
      end)

      stub(Plausible.HTTPClient.Mock, :get, fn
        "https://sandbox-api.paddle.com/products" <> _, _headers ->
          {:ok,
           ok_response(%{
             "data" => [],
             "meta" => %{"has_more" => false}
           })}
      end)

      assert %{
               "123" => %{billing_product_id: "prod_123", billing_price_id: "price_456"}
             } = Migration.sync_enterprise()
    end
  end

  defp ok_response(body, status \\ 200) do
    %Finch.Response{status: status, headers: [{"content-type", "application/json"}], body: body}
  end
end
