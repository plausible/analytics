defmodule Plausible.Billing.MigrationAuditTest do
  use Plausible.DataCase, async: true

  alias Plausible.Billing.MigrationAudit
  alias Plausible.Billing.Subscription

  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.Subscription.Status

  @v1_growth_plan_id "558018"
  @v5_starter_plan_id "910413"

  describe "plan_resolution/1" do
    test "classifies every kind of live subscription" do
      new_user() |> subscribe_to_plan(@v1_growth_plan_id)
      new_user() |> subscribe_to_plan(@v5_starter_plan_id)
      new_user() |> subscribe_to_plan("free_10k")
      new_user() |> subscribe_to_plan(Subscription.manual_plan_id())
      new_user() |> subscribe_to_enterprise_plan()
      unresolved_user = new_user() |> subscribe_to_plan("some-unknown-plan")

      result = MigrationAudit.plan_resolution()

      assert result.total == 6

      assert Map.new(result.by_category, &{&1.category, &1.subscriptions}) == %{
               "v1 growth" => 1,
               "v5 starter" => 1,
               "free" => 1,
               "manual" => 1,
               "enterprise" => 1,
               "unresolved" => 1
             }

      unresolved_team = team_of(unresolved_user)

      assert [
               %{
                 team_id: team_id,
                 paddle_plan_id: "some-unknown-plan",
                 status: :active
               }
             ] = result.unresolved

      assert team_id == unresolved_team.id
    end

    test "counts a subscription whose paid period is over only when it isn't expired" do
      today = ~D[2026-10-20]

      expired = [status: Status.deleted(), next_bill_date: Date.shift(today, day: -1)]
      paid_up = [status: Status.deleted(), next_bill_date: today]

      new_user() |> subscribe_to_plan(@v1_growth_plan_id, expired)
      new_user() |> subscribe_to_plan(@v1_growth_plan_id, paid_up)
      new_user() |> subscribe_to_plan(@v1_growth_plan_id, status: Status.paused())
      new_user() |> subscribe_to_plan(@v1_growth_plan_id, status: Status.past_due())

      result = MigrationAudit.plan_resolution(today: today)

      assert result.total == 3
      assert Map.new(result.by_category, &{&1.category, &1.subscriptions}) == %{"v1 growth" => 3}
    end

    test "the :current scope audits only the last subscription of each team" do
      user = new_user()
      team = user |> subscribe_to_plan(@v1_growth_plan_id) |> team_of()
      insert(:subscription, team: team, paddle_plan_id: @v5_starter_plan_id)

      result = MigrationAudit.plan_resolution(scope: :current)

      assert result.total == 1
      assert Map.new(result.by_category, &{&1.category, &1.subscriptions}) == %{"v5 starter" => 1}
      assert result.teams_with_multiple_subscriptions == %{any_status: 1, live: 1}
    end

    test "reports teams with more than one live subscription separately" do
      team = new_user() |> subscribe_to_plan(@v1_growth_plan_id) |> team_of()

      insert(:subscription,
        team: team,
        paddle_plan_id: @v5_starter_plan_id,
        status: Status.deleted(),
        next_bill_date: ~D[2020-01-01]
      )

      result = MigrationAudit.plan_resolution()

      assert result.teams_with_multiple_subscriptions == %{any_status: 1, live: 0}
    end

    test "summarises generations and plan ids in use" do
      new_user() |> subscribe_to_plan(@v1_growth_plan_id)
      new_user() |> subscribe_to_plan(@v1_growth_plan_id)

      result = MigrationAudit.plan_resolution()

      assert [%{subscriptions: 2, distinct_plan_ids_in_use: 1, plan_ids_in_files: files}] =
               Enum.filter(result.by_generation, &(&1.generation == 1))

      assert files > 0

      assert [%{paddle_plan_id: @v1_growth_plan_id, category: "v1 growth", subscriptions: 2}] =
               result.by_plan_id
    end

    test "summarises enterprise plans by their subscriptions" do
      new_user() |> subscribe_to_enterprise_plan()

      new_user()
      |> subscribe_to_enterprise_plan(
        subscription: [status: Status.deleted(), next_bill_date: ~D[2020-01-01]]
      )

      new_user() |> subscribe_to_enterprise_plan(subscription?: false)

      result = MigrationAudit.plan_resolution()

      assert result.enterprise_plans == %{
               total: 3,
               attached_to_live_subscription: 1,
               attached_to_any_subscription: 2
             }
    end

    test "an empty database gives an empty report" do
      result = MigrationAudit.plan_resolution()

      assert result.total == 0
      assert result.unresolved == []
      assert result.by_category == []
    end
  end

  describe "run/1" do
    test "prints both reports and returns the data" do
      new_user() |> subscribe_to_plan("some-unknown-plan")

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert %{plan_resolution: %{total: 1}, plan_files: plan_files} = MigrationAudit.run()
          assert is_list(plan_files)
        end)

      assert output =~ "UNRESOLVED subscriptions (1)"
      assert output =~ "Plan files:"
      assert output =~ "Subscribers (as of"
      assert output =~ "Classic catalog and modifiers skipped"
    end

    test "with catalog: true it also audits the Classic catalog" do
      plans = [%{"id" => 1, "recurring_price" => %{"USD" => "9.00", "EUR" => "9.00"}}]

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert %{classic_catalog: %{plans: %{total: 1}, modifiers: %{total: 0}}} =
                   MigrationAudit.run(catalog: true, plans: plans, modifiers: [])
        end)

      assert output =~ "Classic catalog: 1 plans"
      assert output =~ "Modifiers: 0"
    end

    test "reports a failing Classic call without raising" do
      defmodule BrokenApi do
        def list_plans(), do: {:error, :timeout}
        def list_modifiers(), do: {:ok, []}
      end

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert %{classic_catalog: %{error: %{failed_call: :plans, reason: ":timeout"}}} =
                   MigrationAudit.run(catalog: true, api: BrokenApi)
        end)

      assert output =~ "failed to fetch plans: :timeout"
    end
  end

  describe "json_report/1" do
    test "runs everything including the catalog and returns shareable JSON" do
      new_user() |> subscribe_to_plan("some-unknown-plan")
      plans = [%{"id" => 1, "recurring_price" => %{"USD" => "9.00", "EUR" => "9.00"}}]

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          json = MigrationAudit.json_report(plans: plans, modifiers: [])
          send(self(), {:json, json})
        end)

      assert output == ""
      assert_received {:json, json}

      decoded = Jason.decode!(json)

      assert decoded["classic_catalog"]["plans"]["total"] == 1
      assert decoded["classic_catalog"]["plans"]["multi_currency"] == 1
      assert decoded["plan_resolution"]["unresolved"]["count"] == 1
      assert is_list(decoded["subscribers"]["billed"])

      refute json =~ "team_id"
      refute json =~ "subscription_id"
    end

    test "reports a failing Classic call in the JSON instead of raising" do
      defmodule JsonBrokenApi do
        def list_plans(), do: {:error, :timeout}
        def list_modifiers(), do: {:ok, []}
      end

      decoded = MigrationAudit.json_report(api: JsonBrokenApi) |> Jason.decode!()

      assert decoded["classic_catalog"] == %{
               "error" => %{"failed_call" => "plans", "reason" => ":timeout"}
             }

      assert is_map(decoded["plan_resolution"])
    end
  end

  describe "to_json/1" do
    test "encodes results with dates, atoms, tuples and decimals" do
      new_user() |> subscribe_to_plan(@v1_growth_plan_id)
      new_user() |> subscribe_to_plan("some-unknown-plan")

      {result, _output} =
        ExUnit.CaptureIO.with_io(fn ->
          MigrationAudit.run(catalog: true, plans: [], modifiers: [])
        end)

      decoded = result |> MigrationAudit.to_json() |> Jason.decode!()

      assert decoded["plan_resolution"]["total"] == 2

      assert Enum.sort(decoded["plan_resolution"]["by_category"]) == [
               %{"category" => "unresolved", "subscriptions" => 1},
               %{"category" => "v1 growth", "subscriptions" => 1}
             ]

      assert is_binary(decoded["subscribers"]["as_of"])
      assert decoded["subscribers"]["billed"] |> is_list()
    end
  end

  describe "plan_files_integrity/1" do
    test "the plan files in priv are consistent" do
      assert MigrationAudit.plan_files_integrity() == []
    end

    test "reports files that can't be read" do
      dir = System.tmp_dir!() |> Path.join("audit_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(Path.join(dir, "plans_v1.json"), "not json")

      problems = MigrationAudit.plan_files_integrity(priv_dir: dir)

      assert Enum.any?(problems, &(&1.check == :unreadable and &1.file == "plans_v1"))
      assert Enum.any?(problems, &(&1.check == :unreadable and &1.file == "plans_v2"))
      assert Enum.any?(problems, &(&1.check == :unreadable and &1.file == "plan_prices.json"))
    end
  end

  describe "check_plan_files/2" do
    test "accepts consistent files" do
      assert MigrationAudit.check_plan_files(valid_files(), valid_prices()) == []
    end

    test "flags a generation that doesn't match the file" do
      files = put_in(valid_files(), ["plans_v1", Access.at(0), "generation"], 2)
      assert :generation_mismatch in checks(files, valid_prices())
    end

    test "flags ids that aren't numeric" do
      files = put_in(valid_files(), ["plans_v1", Access.at(0), "monthly_product_id"], "pri_123")
      assert :bad_id_format in checks(files, valid_prices())
    end

    test "flags a plan that uses one id for both intervals" do
      files = put_in(valid_files(), ["plans_v1", Access.at(0), "yearly_product_id"], "1")
      assert :same_monthly_and_yearly_id in checks(files, valid_prices())
    end

    test "flags an id used by two plans" do
      files = put_in(valid_files(), ["plans_v1", Access.at(1), "monthly_product_id"], "1")

      problems = MigrationAudit.check_plan_files(files, valid_prices())

      assert [%{check: :duplicate_id, message: message}] =
               Enum.filter(problems, &(&1.check == :duplicate_id))

      assert message =~ "plans_v1 monthly_product_id"
    end

    test "flags two plans with the same kind and pageview limit" do
      files = put_in(valid_files(), ["plans_v1", Access.at(1), "monthly_pageview_limit"], 10_000)

      assert :duplicate_plan in checks(files, valid_prices())
    end

    test "flags missing, orphaned and invalid prices" do
      prices =
        valid_prices()
        |> Map.delete("1")
        |> Map.put("999", 5)
        |> Map.put("2", 0)

      assert checks(valid_files(), prices) == [:bad_price, :missing_price, :orphan_price]
    end

    test "reports unreadable files and prices" do
      files = Map.put(valid_files(), "plans_v2", {:error, "plans_v2.json: no such file"})

      problems =
        MigrationAudit.check_plan_files(files, {:error, "plan_prices.json: no such file"})

      assert Enum.map(problems, & &1.check) == [:unreadable, :unreadable]
    end
  end

  defp checks(files, prices) do
    files |> MigrationAudit.check_plan_files(prices) |> Enum.map(& &1.check) |> Enum.sort()
  end

  defp plan(limit, monthly, yearly) do
    %{
      "kind" => "growth",
      "generation" => 1,
      "monthly_pageview_limit" => limit,
      "monthly_product_id" => monthly,
      "yearly_product_id" => yearly,
      "site_limit" => 50,
      "team_member_limit" => "unlimited",
      "features" => ["goals"]
    }
  end

  defp valid_files() do
    %{
      "plans_v1" => [plan(10_000, "1", "2"), plan(100_000, "3", "4")]
    }
  end

  defp valid_prices(), do: %{"1" => 6, "2" => 60, "3" => 12, "4" => 120}
end
