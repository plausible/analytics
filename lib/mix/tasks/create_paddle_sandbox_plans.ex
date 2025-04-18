defmodule Mix.Tasks.CreatePaddleSandboxPlans do
  @moduledoc """
  Utility for creating Sandbox plans that are used on staging. The `filename`
  argument should be the name of the JSON file containing the production plans.
  E.g.: `plans_v4.json`.

  Unfortunately, there's no API in Paddle that would allow "bulk creating"
  plans - it has to be done through the UI. As a hack though, we can automate
  the process by copying the curl request with the help of browser devtools.

  Therefore, this Mix.Task **does not work out of the box** and the actual curl
  command that it executes must be replaced by the developer. Here's how:

  0) Obtain access to the Sandbox Paddle account and log in
  1) Navigate to https://sandbox-vendors.paddle.com/subscriptions/plans
  2) Click the "+ New Plan" button to open the form
  3) Open browser devtools, fill in the required fields and submit the form
  4) Find the POST request from the "Network" tab and copy it as cURL
  5) Come back here and paste it into the `create_paddle_plan` function
  6) Replace the params within the string with the real params (these should
     be available in the function already)

  Once the plans are created successfully, the task will also fetch the IDs
  (i.e. paddle_plan_id's) and write the `sandbox_plans_v*.json` file (which is
  basically the same set of production plans but with `monthly_product_id` and
  `yearly_product_id` replaced with the sandbox ones).
  """

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

    create_local_sandbox_plans_json_file(prod_plans, file_path_to_write, paddle_plans_after)

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

    case curl_quietly(curl_command) do
      :ok ->
        IO.puts("✅ Created #{name}")

      {:error, reason} ->
        IO.puts("❌ Halting. The plan #{name} could not be created. Error: #{reason}")
        System.halt(1)
    end
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

  defp fetch_all_sandbox_plans() do
    paddle_config = Application.get_env(:plausible, :paddle)

    url = "https://sandbox-vendors.paddle.com/api/2.0/subscription/plans"

    body =
      JSON.encode!(%{
        vendor_id: paddle_config[:vendor_id],
        vendor_auth_code: paddle_config[:vendor_auth_code]
      })

    headers = [
      {"Content-type", "application/json"},
      {"Accept", "application/json"}
    ]

    request = Finch.build(:post, url, headers, body)

    with {:ok, response} <- Finch.request(request, MyFinch),
         {:ok, %{"success" => true, "response" => plans} = body} <- JSON.decode(response.body) do
      IO.puts("✅ Successfully fetched #{body["count"]}/#{body["total"]} sandbox plans")
      plans
    else
      error ->
        IO.puts("❌ Failed to fetch plans from Paddle - #{inspect(error)}")
        System.halt(1)
    end
  end

  defp create_local_sandbox_plans_json_file(prod_plans, filepath, paddle_plans) do
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
      end)

    File.write!(filepath, JSON.encode!(sandbox_plans))
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

  defp plan_name(plan, type) do
    generation = "v#{plan["generation"]}"
    kind = plan["kind"]
    volume = plan["monthly_pageview_limit"] |> PlausibleWeb.StatsView.large_number_format()

    [generation, type, kind, volume] |> Enum.join("_")
  end

  defp curl_quietly(cmd) do
    cmd = String.replace(cmd, "curl", ~s|curl -s -o /dev/null -w "%{http_code}"|)

    case System.cmd("sh", ["-c", cmd], stderr_to_stdout: true) do
      {"302", 0} ->
        :ok

      {http_status, 0} ->
        {:error, "unexpected HTTP response status (#{http_status}). Expected 302."}

      {_, exit_code} ->
        {:error, "curl command exited with exit code #{exit_code}"}
    end
  end
end
