defmodule Plausible.Billing.PaddleBilling.MigrationTest do
  use Plausible.DataCase

  import Mox

  alias Plausible.Billing.PaddleBilling.Migration

  setup :verify_on_exit!

  describe "sync_enterprise" do
    test "syncs new enterprise plan" do
      team = new_site().team

      insert(:enterprise_plan,
        team: team,
        monthly_pageview_limit: 200_000,
        billing_interval: :monthly,
        site_limit: 50,
        hourly_api_request_limit: 2000,
        team_member_limit: 20,
        features: [Plausible.Billing.Feature.SitesAPI],
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

        "https://sandbox-api.paddle.com/products", _headers, params ->
          assert %{
                   name: "Plausible Enterprise 200k/50 sites/20 members/2k API calls/Sites API",
                   type: "custom",
                   custom_data: %{
                     "canonical_enterprise_plan" => %{
                       features: [Plausible.Billing.Feature.SitesAPI],
                       monthly_pageview_limit: 200_000,
                       billing_interval: :monthly,
                       paddle_plan_id: "123",
                       site_limit: 50,
                       hourly_api_request_limit: 2000,
                       team_member_limit: 20
                     },
                     "enterprise" => true
                   },
                   tax_category: "saas"
                 } = params

          {:ok,
           ok_response(
             %{
               "data" => %{
                 "id" => "prod_123"
               }
             },
             201
           )}

        "https://sandbox-api.paddle.com/prices", _headers, params ->
          assert %{
                   type: "custom",
                   description: "[enterprise] monthly (Classic plan 123)",
                   quantity: %{maximum: 1, minimum: 1},
                   tax_mode: :account_setting,
                   custom_data: %{"paddle_classic_plan_id" => "123"},
                   billing_cycle: %{interval: "month", frequency: 1},
                   product_id: "prod_123",
                   unit_price: %{amount: "900", currency_code: :USD},
                   unit_price_overrides: []
                 } = params

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

    test "updates existing enterprise plan" do
      team = new_site().team

      insert(:enterprise_plan,
        team: team,
        monthly_pageview_limit: 200_000,
        billing_interval: :monthly,
        site_limit: 50,
        hourly_api_request_limit: 2000,
        team_member_limit: 20,
        features: [Plausible.Billing.Feature.SitesAPI],
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
      end)

      stub(Plausible.HTTPClient.Mock, :patch, fn
        "https://sandbox-api.paddle.com/products/prod_123", _headers, params ->
          assert %{
                   name: "Plausible Enterprise 200k/50 sites/20 members/2k API calls/Sites API",
                   custom_data: %{
                     "canonical_enterprise_plan" => %{
                       features: [Plausible.Billing.Feature.SitesAPI],
                       monthly_pageview_limit: 200_000,
                       billing_interval: :monthly,
                       paddle_plan_id: "123",
                       site_limit: 50,
                       hourly_api_request_limit: 2000,
                       team_member_limit: 20
                     },
                     "enterprise" => true
                   }
                 } = params

          {:ok,
           ok_response(
             %{
               "data" => %{
                 "id" => "prod_123"
               }
             },
             200
           )}

        "https://sandbox-api.paddle.com/prices/price_456", _headers, params ->
          assert %{
                   description: "[enterprise] monthly (Classic plan 123)",
                   custom_data: %{"paddle_classic_plan_id" => "123"},
                   unit_price: %{amount: "900", currency_code: :USD}
                 } = params

          {:ok,
           ok_response(
             %{
               "data" => %{
                 "id" => "price_456"
               }
             },
             200
           )}
      end)

      stub(Plausible.HTTPClient.Mock, :get, fn
        "https://sandbox-api.paddle.com/products" <> _, _headers ->
          {:ok,
           ok_response(%{
             "data" => [
               %{
                 "id" => "prod_123",
                 "prices" => [
                   %{
                     "id" => "price_456",
                     "custom_data" => %{
                       "paddle_classic_plan_id" => "123"
                     }
                   }
                 ],
                 "custom_data" => %{
                   "canonical_enterprise_plan" => %{
                     "paddle_plan_id" => "123"
                   },
                   "enterprise" => true
                 }
               }
             ],
             "meta" => %{"has_more" => false}
           })}
      end)

      assert %{
               "123" => %{billing_product_id: "prod_123", billing_price_id: "price_456"}
             } = Migration.sync_enterprise(true)
    end
  end

  describe "enterprise_product_name" do
    test "works" do
      team = new_site().team

      ep =
        build(:enterprise_plan,
          team: team,
          monthly_pageview_limit: 1_000_000,
          billing_interval: :yearly,
          site_limit: 10,
          hourly_api_request_limit: 600,
          team_member_limit: :unlimited,
          features: [Plausible.Billing.Feature.Funnels],
          paddle_plan_id: "123"
        )

      assert Migration.enterprise_product_name(ep) ==
               "Plausible Enterprise 1M/10 sites"

      ep =
        build(:enterprise_plan,
          team: team,
          monthly_pageview_limit: 1_000_000,
          billing_interval: :yearly,
          site_limit: 10,
          hourly_api_request_limit: 600,
          team_member_limit: 20,
          features: [],
          paddle_plan_id: "123"
        )

      assert Migration.enterprise_product_name(ep) ==
               "Plausible Enterprise 1M/10 sites/20 members"

      ep =
        build(:enterprise_plan,
          team: team,
          monthly_pageview_limit: 1_000_000,
          billing_interval: :yearly,
          site_limit: 10,
          hourly_api_request_limit: 2500,
          team_member_limit: :unlimited,
          features: [],
          paddle_plan_id: "123"
        )

      assert Migration.enterprise_product_name(ep) ==
               "Plausible Enterprise 1M/10 sites/2.5k API calls"

      ep =
        build(:enterprise_plan,
          team: team,
          monthly_pageview_limit: 200_000,
          billing_interval: :monthly,
          site_limit: 50,
          hourly_api_request_limit: 2000,
          team_member_limit: 20,
          features: [Plausible.Billing.Feature.SitesAPI],
          paddle_plan_id: "123"
        )

      assert Migration.enterprise_product_name(ep) ==
               "Plausible Enterprise 200k/50 sites/20 members/2k API calls/Sites API"

      ep =
        build(:enterprise_plan,
          team: team,
          monthly_pageview_limit: 200_000,
          billing_interval: :monthly,
          site_limit: 50,
          hourly_api_request_limit: 2000,
          team_member_limit: 20,
          features: [Plausible.Billing.Feature.SitesAPI, Plausible.Billing.Feature.SSO],
          paddle_plan_id: "123"
        )

      assert Migration.enterprise_product_name(ep) ==
               "Plausible Enterprise 200k/50 sites/20 members/2k API calls/Sites API,Single Sign-On"
    end
  end

  defp ok_response(body, status \\ 200) do
    %Finch.Response{status: status, headers: [{"content-type", "application/json"}], body: body}
  end
end
