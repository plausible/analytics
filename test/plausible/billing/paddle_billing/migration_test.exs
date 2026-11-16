defmodule Plausible.Billing.PaddleBilling.MigrationTest do
  use Plausible.DataCase
  @moduletag :ee_only

  import ExUnit.CaptureIO
  import Mox

  alias Plausible.Billing.PaddleBilling.Migration
  alias Plausible.Billing.Plans

  setup :verify_on_exit!

  describe "sync_standard" do
    test "creates products and prices for given plans" do
      plans = [plan(:growth, "10k", 4), plan(:growth, "150M", 1)]

      stub_standard_post()
      stub_empty_products()

      assert sync_standard(false, plans) == %{
               "857097" => %{
                 billing_product_id: "prod_Growth (10k)",
                 billing_price_id: "price_857097"
               },
               "857079" => %{
                 billing_product_id: "prod_Growth (10k)",
                 billing_price_id: "price_857079"
               },
               "648089" => %{
                 billing_product_id: "prod_Growth (150M)",
                 billing_price_id: "price_648089"
               }
             }
    end

    test "sends product and price details" do
      test_pid = self()

      stub(Plausible.HTTPClient.Mock, :post, fn
        "https://sandbox-api.paddle.com/products", _headers, params ->
          send(test_pid, {:product, params})
          {:ok, ok_response(%{"data" => %{"id" => "prod_1"}}, 201)}

        "https://sandbox-api.paddle.com/prices", _headers, params ->
          send(test_pid, {:price, params})
          {:ok, ok_response(%{"data" => %{"id" => "price_1"}}, 201)}
      end)

      stub_empty_products()

      sync_standard(false, [plan(:growth, "10k", 4)])

      assert_received {:product, product}

      assert %{
               name: "Growth (10k)",
               type: "standard",
               description: "[v4] Growth (10k)",
               tax_category: "saas",
               custom_data: %{
                 canonical_plan: %{monthly_product_id: "857097", yearly_product_id: "857079"}
               }
             } = product

      assert_received {:price, monthly}
      assert_received {:price, yearly}

      assert %{
               description: "[v4] monthly Growth (10k)",
               billing_cycle: %{interval: "month", frequency: 1},
               unit_price: %{amount: "900", currency_code: :USD},
               custom_data: %{"paddle_classic_plan_id" => "857097"},
               product_id: "prod_1",
               type: "standard",
               unit_price_overrides: [
                 %{unit_price: %{currency_code: "EUR"}},
                 %{country_codes: ["GB"], unit_price: %{currency_code: "GBP"}}
               ]
             } = monthly

      assert %{
               description: "[v4] yearly Growth (10k)",
               billing_cycle: %{interval: "year", frequency: 1},
               unit_price: %{amount: "9000", currency_code: :USD},
               custom_data: %{"paddle_classic_plan_id" => "857079"}
             } = yearly
    end

    test "creates a single price and no overrides for a yearly-only, single currency plan" do
      test_pid = self()

      stub(Plausible.HTTPClient.Mock, :post, fn
        "https://sandbox-api.paddle.com/products", _headers, _params ->
          {:ok, ok_response(%{"data" => %{"id" => "prod_1"}}, 201)}

        "https://sandbox-api.paddle.com/prices", _headers, params ->
          send(test_pid, {:price, params})
          {:ok, ok_response(%{"data" => %{"id" => "price_1"}}, 201)}
      end)

      stub_empty_products()

      assert %{"648089" => _} =
               mapping = sync_standard(false, [plan(:growth, "150M", 1)])

      assert map_size(mapping) == 1

      assert_received {:price, %{unit_price_overrides: [], billing_cycle: %{interval: "year"}}}
      refute_received {:price, _}
    end

    test "creates nothing for existing plans and returns their mapping" do
      stub_existing_products()

      stub(Plausible.HTTPClient.Mock, :post, fn _url, _headers, _params ->
        flunk("unexpected request")
      end)

      assert sync_standard(false, [plan(:growth, "10k", 4)]) == %{
               "857097" => %{billing_product_id: "prod_123", billing_price_id: "price_monthly"},
               "857079" => %{billing_product_id: "prod_123", billing_price_id: "price_yearly"}
             }
    end

    test "creates only the plans that are missing" do
      stub_existing_products()
      stub_standard_post()

      mapping =
        sync_standard(false, [plan(:growth, "10k", 4), plan(:growth, "150M", 1)])

      assert mapping["857097"].billing_product_id == "prod_123"

      assert mapping["648089"] == %{
               billing_product_id: "prod_Growth (150M)",
               billing_price_id: "price_648089"
             }
    end

    test "updates existing products and prices with overwrite" do
      test_pid = self()
      stub_existing_products()

      stub(Plausible.HTTPClient.Mock, :patch, fn url, _headers, params ->
        send(test_pid, {:patch, url, params})
        {:ok, ok_response(%{"data" => %{"id" => url |> String.split("/") |> List.last()}})}
      end)

      stub(Plausible.HTTPClient.Mock, :post, fn _url, _headers, _params ->
        flunk("unexpected request")
      end)

      assert sync_standard(true, [plan(:growth, "10k", 4)]) == %{
               "857097" => %{billing_product_id: "prod_123", billing_price_id: "price_monthly"},
               "857079" => %{billing_product_id: "prod_123", billing_price_id: "price_yearly"}
             }

      assert_received {:patch, "https://sandbox-api.paddle.com/products/prod_123",
                       %{name: "Growth (10k)", description: "[v4] Growth (10k)"}}

      assert_received {:patch, "https://sandbox-api.paddle.com/prices/price_monthly",
                       %{
                         description: "[v4] monthly Growth (10k)",
                         unit_price: %{amount: "900", currency_code: :USD}
                       }}

      assert_received {:patch, "https://sandbox-api.paddle.com/prices/price_yearly",
                       %{description: "[v4] yearly Growth (10k)"}}
    end

    test "creates a missing price of an existing product with overwrite" do
      stub(Plausible.HTTPClient.Mock, :get, fn "https://sandbox-api.paddle.com/products" <> _,
                                               _headers ->
        {:ok,
         ok_response(%{
           "data" => [
             %{
               "id" => "prod_123",
               "custom_data" => growth_10k_custom_data(),
               "prices" => [
                 %{
                   "id" => "price_monthly",
                   "custom_data" => %{"paddle_classic_plan_id" => "857097"}
                 }
               ]
             }
           ],
           "meta" => %{"has_more" => false}
         })}
      end)

      stub(Plausible.HTTPClient.Mock, :patch, fn url, _headers, _params ->
        {:ok, ok_response(%{"data" => %{"id" => url |> String.split("/") |> List.last()}})}
      end)

      stub(Plausible.HTTPClient.Mock, :post, fn
        "https://sandbox-api.paddle.com/prices", _headers, %{product_id: "prod_123"} = params ->
          assert params.custom_data == %{"paddle_classic_plan_id" => "857079"}
          {:ok, ok_response(%{"data" => %{"id" => "price_yearly"}}, 201)}
      end)

      assert %{
               "857097" => %{billing_price_id: "price_monthly"},
               "857079" => %{billing_product_id: "prod_123", billing_price_id: "price_yearly"}
             } = sync_standard(true, [plan(:growth, "10k", 4)])
    end
  end

  describe "update_plan_files" do
    @describetag :tmp_dir

    test "writes billing ids into plans matched by Classic ids", %{tmp_dir: dir} do
      path = Path.join(dir, "plans_v4.json")
      File.write!(path, JSON.encode!(plans_fixture("857097", "857079", "857098", nil)))
      stub_billing_products()

      assert :ok = update_plan_files(dir, ["plans_v4"])

      assert [p10k, p100k] = path |> File.read!() |> JSON.decode!()

      assert %{
               "billing_product_id" => "prod_10k",
               "billing_monthly_price_id" => "price_10k_m",
               "billing_yearly_price_id" => "price_10k_y"
             } = p10k

      assert %{
               "billing_product_id" => "prod_100k",
               "billing_monthly_price_id" => "price_100k_m",
               "billing_yearly_price_id" => nil
             } = p100k
    end

    test "keeps the key order and appends the new keys", %{tmp_dir: dir} do
      path = Path.join(dir, "plans_v4.json")
      File.write!(path, JSON.encode!(plans_fixture("857097", "857079", "857098", nil)))
      stub_billing_products()

      keys_before = plan_keys(path)

      update_plan_files(dir, ["plans_v4"])
      raw = File.read!(path)

      assert plan_keys(path) ==
               keys_before ++
                 ["billing_product_id", "billing_monthly_price_id", "billing_yearly_price_id"]

      update_plan_files(dir, ["plans_v4"])
      assert File.read!(path) == raw
    end

    test "raises when a plan isn't in Paddle Billing", %{tmp_dir: dir} do
      File.write!(
        Path.join(dir, "plans_v4.json"),
        JSON.encode!(plans_fixture("857097", "857079", "000000", nil))
      )

      stub_billing_products()

      assert_raise KeyError, fn -> update_plan_files(dir, ["plans_v4"]) end
    end
  end

  describe "update_sandbox_plan_files" do
    @describetag :tmp_dir

    setup %{tmp_dir: dir} do
      File.write!(
        Path.join(dir, "plans_v4.json"),
        JSON.encode!(plans_fixture("857097", "857079", "857098", nil))
      )

      File.write!(
        Path.join(dir, "sandbox_plans_v4.json"),
        JSON.encode!(plans_fixture("63842", "63843", "63844", nil))
      )

      stub_billing_products()

      :ok
    end

    test "writes billing ids into sandbox plans matched by generation, kind and volume", %{
      tmp_dir: dir
    } do
      assert :ok = update_sandbox_plan_files(dir, ["plans_v4"])

      assert [p10k, p100k] =
               dir |> Path.join("sandbox_plans_v4.json") |> File.read!() |> JSON.decode!()

      assert %{
               "monthly_product_id" => "63842",
               "yearly_product_id" => "63843",
               "billing_product_id" => "prod_10k",
               "billing_monthly_price_id" => "price_10k_m",
               "billing_yearly_price_id" => "price_10k_y"
             } = p10k

      assert %{
               "billing_product_id" => "prod_100k",
               "billing_monthly_price_id" => "price_100k_m",
               "billing_yearly_price_id" => nil
             } = p100k
    end

    test "is idempotent", %{tmp_dir: dir} do
      path = Path.join(dir, "sandbox_plans_v4.json")

      update_sandbox_plan_files(dir, ["plans_v4"])
      first = File.read!(path)
      update_sandbox_plan_files(dir, ["plans_v4"])

      assert File.read!(path) == first
    end

    test "raises when the production plan isn't in Paddle Billing", %{tmp_dir: dir} do
      File.write!(
        Path.join(dir, "plans_v4.json"),
        JSON.encode!(plans_fixture("857097", "857079", "000000", nil))
      )

      assert_raise KeyError, fn -> update_sandbox_plan_files(dir, ["plans_v4"]) end
    end
  end

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
                   type: "standard",
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
                   type: "standard",
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
             } = sync_enterprise()
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

      expect(Plausible.HTTPClient.Mock, :patch, 2, fn
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
             } = sync_enterprise(true)
    end

    test "creates nothing for existing plans without overwrite" do
      insert_enterprise_plan("123")
      stub_classic_plans([%{"id" => 123, "recurring_price" => %{"USD" => "9.000"}}])
      stub_existing_enterprise_products()

      stub(Plausible.HTTPClient.Mock, :patch, fn url, _headers, _params ->
        flunk("unexpected PATCH #{url}")
      end)

      assert sync_enterprise() == %{
               "123" => %{billing_product_id: "prod_123", billing_price_id: "price_456"}
             }
    end

    test "skips plans that Classic doesn't know" do
      insert_enterprise_plan("123")
      insert_enterprise_plan("456")
      stub_classic_plans([%{"id" => 123, "recurring_price" => %{"USD" => "9.000"}}])
      stub_empty_products()

      stub(Plausible.HTTPClient.Mock, :post, fn
        "https://vendors.paddle.com/api/2.0/subscription/plans", _headers, _params ->
          {:ok,
           classic_plans_response([%{"id" => 123, "recurring_price" => %{"USD" => "9.000"}}])}

        "https://sandbox-api.paddle.com/products", _headers, _params ->
          {:ok, ok_response(%{"data" => %{"id" => "prod_123"}}, 201)}

        "https://sandbox-api.paddle.com/prices", _headers, _params ->
          {:ok, ok_response(%{"data" => %{"id" => "price_123"}}, 201)}
      end)

      assert sync_enterprise() == %{
               "123" => %{billing_product_id: "prod_123", billing_price_id: "price_123"}
             }
    end

    test "raises without sending any write when a plan has no recurring price" do
      insert_enterprise_plan("123")
      insert_enterprise_plan("456")

      stub_classic_plans([
        %{"id" => 123, "recurring_price" => %{"USD" => "9.000"}},
        %{"id" => 456, "recurring_price" => %{}}
      ])

      stub_empty_products()

      assert_raise MatchError, fn -> sync_enterprise() end
    end

    test "raises without sending any write when a plan has several recurring prices" do
      insert_enterprise_plan("123")
      insert_enterprise_plan("456")

      stub_classic_plans([
        %{"id" => 123, "recurring_price" => %{"USD" => "9.000"}},
        %{"id" => 456, "recurring_price" => %{"USD" => "9.000", "EUR" => "8.000"}}
      ])

      stub_empty_products()

      assert_raise MatchError, fn -> sync_enterprise() end
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

  defp sync_standard(overwrite?, plans) do
    {mapping, _progress} = with_io(fn -> Migration.sync_standard(overwrite?, plans) end)
    mapping
  end

  defp sync_enterprise(overwrite? \\ false) do
    {mapping, _progress} = with_io(fn -> Migration.sync_enterprise(overwrite?) end)
    mapping
  end

  defp update_plan_files(dir, plan_files) do
    {result, _io} = with_io(fn -> Migration.update_plan_files(dir, plan_files) end)
    result
  end

  defp update_sandbox_plan_files(dir, plan_files) do
    {result, _io} = with_io(fn -> Migration.update_sandbox_plan_files(dir, plan_files) end)
    result
  end

  defp stub_billing_products() do
    stub(Plausible.HTTPClient.Mock, :get, fn "https://sandbox-api.paddle.com/products" <> _,
                                             _headers ->
      {:ok,
       ok_response(%{
         "data" => [
           product("prod_10k", %{"857097" => "price_10k_m", "857079" => "price_10k_y"}),
           product("prod_100k", %{"857098" => "price_100k_m"})
         ],
         "meta" => %{"has_more" => false}
       })}
    end)
  end

  defp plans_fixture(p10k_monthly, p10k_yearly, p100k_monthly, p100k_yearly) do
    for {limit, monthly, yearly} <- [
          {10_000, p10k_monthly, p10k_yearly},
          {100_000, p100k_monthly, p100k_yearly}
        ] do
      %{
        "kind" => "growth",
        "generation" => 4,
        "monthly_pageview_limit" => limit,
        "monthly_product_id" => monthly,
        "yearly_product_id" => yearly,
        "site_limit" => 10,
        "team_member_limit" => 3,
        "features" => ["goals"]
      }
    end
  end

  defp plan_keys(path) do
    [first_plan | _] = path |> File.read!() |> Jason.decode!(objects: :ordered_objects)
    Enum.map(first_plan.values, fn {key, _value} -> key end)
  end

  defp product(id, price_ids_by_classic_id) do
    %{
      "id" => id,
      "custom_data" => %{},
      "prices" =>
        for {classic_id, price_id} <- price_ids_by_classic_id do
          %{"id" => price_id, "custom_data" => %{"paddle_classic_plan_id" => classic_id}}
        end
    }
  end

  defp insert_enterprise_plan(paddle_plan_id) do
    insert(:enterprise_plan,
      team: new_site().team,
      monthly_pageview_limit: 200_000,
      billing_interval: :monthly,
      site_limit: 50,
      hourly_api_request_limit: 2000,
      team_member_limit: 20,
      features: [Plausible.Billing.Feature.SitesAPI],
      paddle_plan_id: paddle_plan_id
    )
  end

  defp classic_plans_response(plans) do
    ok_response(%{
      "success" => true,
      "count" => length(plans),
      "total" => length(plans),
      "response" => plans
    })
  end

  defp stub_classic_plans(plans) do
    stub(Plausible.HTTPClient.Mock, :post, fn
      "https://vendors.paddle.com/api/2.0/subscription/plans", _headers, _params ->
        {:ok, classic_plans_response(plans)}

      url, _headers, _params ->
        flunk("unexpected POST #{url}")
    end)
  end

  defp stub_existing_enterprise_products() do
    stub(Plausible.HTTPClient.Mock, :get, fn "https://sandbox-api.paddle.com/products" <> _,
                                             _headers ->
      {:ok,
       ok_response(%{
         "data" => [
           %{
             "id" => "prod_123",
             "prices" => [
               %{"id" => "price_456", "custom_data" => %{"paddle_classic_plan_id" => "123"}}
             ],
             "custom_data" => %{
               "canonical_enterprise_plan" => %{"paddle_plan_id" => "123"},
               "enterprise" => true
             }
           }
         ],
         "meta" => %{"has_more" => false}
       })}
    end)
  end

  defp plan(kind, volume, generation) do
    Enum.find(
      Plans.all(),
      &(&1.kind == kind and &1.volume == volume and &1.generation == generation)
    )
  end

  defp growth_10k_custom_data() do
    %{"canonical_plan" => %{"monthly_product_id" => "857097", "yearly_product_id" => "857079"}}
  end

  defp stub_empty_products() do
    stub(Plausible.HTTPClient.Mock, :get, fn "https://sandbox-api.paddle.com/products" <> _,
                                             _headers ->
      {:ok, ok_response(%{"data" => [], "meta" => %{"has_more" => false}})}
    end)
  end

  defp stub_existing_products() do
    stub(Plausible.HTTPClient.Mock, :get, fn "https://sandbox-api.paddle.com/products" <> _,
                                             _headers ->
      {:ok,
       ok_response(%{
         "data" => [
           %{
             "id" => "prod_123",
             "custom_data" => growth_10k_custom_data(),
             "prices" => [
               %{
                 "id" => "price_monthly",
                 "custom_data" => %{"paddle_classic_plan_id" => "857097"}
               },
               %{"id" => "price_yearly", "custom_data" => %{"paddle_classic_plan_id" => "857079"}}
             ]
           }
         ],
         "meta" => %{"has_more" => false}
       })}
    end)
  end

  defp stub_standard_post() do
    stub(Plausible.HTTPClient.Mock, :post, fn
      "https://sandbox-api.paddle.com/products", _headers, %{name: name} ->
        {:ok, ok_response(%{"data" => %{"id" => "prod_" <> name}}, 201)}

      "https://sandbox-api.paddle.com/prices", _headers, params ->
        id = "price_" <> params.custom_data["paddle_classic_plan_id"]
        {:ok, ok_response(%{"data" => %{"id" => id}}, 201)}
    end)
  end

  defp ok_response(body, status \\ 200) do
    %Finch.Response{status: status, headers: [{"content-type", "application/json"}], body: body}
  end
end
