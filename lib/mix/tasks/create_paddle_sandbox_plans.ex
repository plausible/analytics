defmodule Mix.Tasks.CreatePaddleSandboxPlans do
  @moduledoc """
  Utility for creating Sandbox plans that are used on staging. The product of
  this task is a `sandbox_plans_v*.json` file matching with the production
  plans, just with the monthly/yearly product_id's of the sandbox plans.

  In principle, this task works like `Mix.Tasks.CreatePaddleProdPlans`, with
  the following differences:

  * The `filename` argument should be the name of the JSON file containing the
    production plans (meaning that those should be created as the first step).
    No special "input file" required.

  * To copy the curl command from the browser, you need to add a plan from
    https://sandbox-vendors.paddle.com/subscriptions/plans. Everything else is
    the same - please see `create_paddle_prod_plans.ex` for instructions.

  * This task can be executed multiple times in a row - it will not create
    duplicates in Sandbox Paddle. On staging we can use a specific plan-naming
    structure to determine whether a plan has been created already. On prod we
    cannot do that since the plan names need to look nice.

  * No need to copy paddle API credentials.

  ## Usage example:

  ```
  mix create_paddle_sandbox_plans plans_v5.json
  ```
  """

  alias Mix.Tasks.CreatePaddleProdPlans
  use Mix.Task

  @requirements ["app.config"]

  def run([filename]) do
    {:ok, _} = Application.ensure_all_started(:telemetry)
    Finch.start_link(name: MyFinch)

    prod_plans =
      Application.app_dir(:plausible, ["priv", filename])
      |> File.read!()
      |> JSON.decode!()

    to_be_created =
      prod_plans
      |> put_prices()
      |> Enum.flat_map(fn priced_plan ->
        [
          create_paddle_plan_attrs(priced_plan, "monthly"),
          create_paddle_plan_attrs(priced_plan, "yearly")
        ]
      end)

    IO.puts("Fetching all sandbox plans before we get started...")
    paddle_plans_before = fetch_all_sandbox_plans()

    created =
      Enum.filter(to_be_created, fn attrs ->
        if Enum.any?(paddle_plans_before, &(&1["name"] == attrs.name)) do
          IO.puts("⚠️ The plan #{attrs.name} already exists in Sandbox Paddle")
          false
        else
          create_paddle_plan(attrs)
          true
        end
      end)

    paddle_plans_after =
      if created != [] do
        IO.puts("⏳ waiting 3s before fetching the newly created plans...")
        Process.sleep(3000)
        IO.puts("Fetching all sandbox plans after creation...")
        fetch_all_sandbox_plans()
      else
        IO.puts("All plans have been created already.")
        paddle_plans_before
      end

    file_path_to_write = Path.join("priv", "sandbox_" <> filename)

    write_sandbox_plans_json_file(prod_plans, file_path_to_write, paddle_plans_after)

    IO.puts("✅ All done! Wrote #{length(prod_plans)} new plans into #{file_path_to_write}!")
  end

  defp create_paddle_plan(%{name: name, price: price, type: type, interval_index: interval_index}) do
    your_unique_token = "abc"

    # Replace this curl command. You might be able to reuse
    # the request body after replacing your unique token.
    curl_command = """
    ... REPLACE ME
    --data-raw '_token=#{your_unique_token}&plan-id=&default-curr=USD&tmpicon=false&name=#{name}&checkout_custom_message=&taxable_type=standard&interval=#{interval_index}&period=1&type=#{type}&trial_length=&price_USD=#{price}&active_EUR=on&price_EUR=#{price}&active_GBP=on&price_GBP=#{price}'
    """

    case CreatePaddleProdPlans.curl_quietly(curl_command) do
      :ok ->
        IO.puts("✅ Created #{name}")

      {:error, reason} ->
        IO.puts("❌ Halting. The plan #{name} could not be created. Error: #{reason}")
        System.halt(1)
    end
  end

  defp fetch_all_sandbox_plans() do
    url = "https://sandbox-vendors.paddle.com/api/2.0/subscription/plans"

    paddle_config = Application.get_env(:plausible, :paddle)

    paddle_credentials = %{
      vendor_id: paddle_config[:vendor_id],
      vendor_auth_code: paddle_config[:vendor_auth_code]
    }

    CreatePaddleProdPlans.fetch_all_paddle_plans(url, paddle_credentials)
  end

  @paddle_interval_indexes %{"monthly" => 2, "yearly" => 5}

  defp create_paddle_plan_attrs(plan_with_price, type) do
    %{
      name: plan_name(plan_with_price, type),
      price: plan_with_price["#{type}_price"],
      type: type,
      interval_index: @paddle_interval_indexes[type]
    }
  end

  defp plan_name(plan, type) do
    generation = "v#{plan["generation"]}"
    kind = plan["kind"]
    volume = plan["monthly_pageview_limit"] |> PlausibleWeb.StatsView.large_number_format()

    [generation, type, kind, volume] |> Enum.join("_")
  end

  defp write_sandbox_plans_json_file(prod_plans, filepath, paddle_plans) do
    sandbox_plans =
      prod_plans
      |> Enum.map(fn prod_plan ->
        monthly_plan_name = plan_name(prod_plan, "monthly")
        yearly_plan_name = plan_name(prod_plan, "yearly")

        %{"id" => sandbox_monthly_product_id} =
          Enum.find(paddle_plans, &(&1["name"] == monthly_plan_name))

        %{"id" => sandbox_yearly_product_id} =
          Enum.find(paddle_plans, &(&1["name"] == yearly_plan_name))

        Map.merge(prod_plan, %{
          "monthly_product_id" => to_string(sandbox_monthly_product_id),
          "yearly_product_id" => to_string(sandbox_yearly_product_id)
        })
        |> CreatePaddleProdPlans.order_keys()
      end)

    content = Jason.encode!(sandbox_plans, pretty: true)
    File.write!(filepath, content)
  end

  defp put_prices(plans) do
    prices =
      Application.app_dir(:plausible, ["priv", "plan_prices.json"])
      |> File.read!()
      |> JSON.decode!()

    plans
    |> Enum.map(fn plan ->
      Map.merge(plan, %{
        "monthly_price" => prices[plan["monthly_product_id"]],
        "yearly_price" => prices[plan["yearly_product_id"]]
      })
    end)
  end
end
