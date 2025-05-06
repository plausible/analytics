defmodule Mix.Tasks.CreatePaddleProdPlans do
  @moduledoc """
  ## Utility for creating Paddle plans for production use.

  Takes a single `filename` argument which should be of format
  `input_plans_v*.json`. That file should live in the `/priv` directory next
  to all other plans and it should contain the necessary information about
  the production plans to be created.

  In order to create the input file:

  * Copy an existing `plans_v*.json` (latest recommended) into the new
    `input_plans_v*.json` file.
  * For every plan object:
    * Adjust the generation, limits, features, etc as desired
    * Replace `monthly_product_id` with a `monthly_price` (integer)
    * Replace `yearly_product_id` with a `yearly_price` (integer)

  After this task is finished successfully, the plans will be created in Paddle
  with the prices given in the input file. With the creation, every plan gets an
  autoincremented ID in Paddle. We will then fetch those exact plans from Paddle
  in an API call and use their monthly and yearly product_id's to write
  `plans_v*.json`. It will be written taking the input file as the "template"
  and replacing the monthly/yearly prices with monthly/yearly product_id's.

  The prices will be written into `/priv/plan_prices.json` (instead of the
  prod plans output file). Note that this separation is intentional - we only
  store prices locally to not rely on Paddle in the dev environment. Otherwise,
  Paddle is considered the "source of truth" of plan prices.

  ## Usage example:

  ```
  mix create_paddle_prod_plans input_plans_v5.json
  ```

  ## Requirement 1: Replace the curl command

  Unfortunately, there's no API in Paddle that would allow "bulk creating"
  plans - it has to be done through the UI. As a hack though, we can automate
  the process by copying the curl request with the help of browser devtools.

  Therefore, this Mix.Task **does not work out of the box** and the actual curl
  command that it executes must be replaced by the developer. Here's how:

  0) Access required to the production Paddle account
  1) Navigate to https://vendors.paddle.com/subscriptions/plans. Chrome or
     Firefox recommended (need to copy a POST request as cURL in a later step)
  2) Click the "+ New Plan" button (top right of the screen) to open the form
  3) Open browser devtools, fill in the required fields and submit the form.
     No need to worry about the form fields since they're provided in this task
     (except `_token`) and they *should work* as long as nothing has changed.
  4) Find the POST request from the "Network" tab and copy it as cURL
  5) Come back here and paste it into the `create_paddle_plan` function
  6) Replace the params within the string with the real params (these should
     be available in the function already)

  ## Requirement 2: Paddle production credentials

  You also need to obtain the Paddle credentials of prod environment (i.e.
  `vendor_id` and `vendor_auth_code`). Those are needed to fetch the plans via
  an actual API call after the plans have been created in Paddle.
  """

  use Mix.Task

  @requirements ["app.config"]

  def run([filename]) do
    {:ok, _} = Application.ensure_all_started(:telemetry)
    Finch.start_link(name: MyFinch)

    if not Regex.match?(~r/^input_plans_v(\d+)\.json$/, filename) do
      raise ArgumentError,
            "Invalid filename argument. Note the strict format - e.g.: \"input_plans_v5.json\""
    end

    input_plans =
      Application.app_dir(:plausible, ["priv", filename])
      |> File.read!()
      |> JSON.decode!()

    to_be_created_in_paddle =
      input_plans
      |> Enum.flat_map(fn plan ->
        [
          create_paddle_plan_attrs(plan, "monthly"),
          create_paddle_plan_attrs(plan, "yearly")
        ]
      end)

    user_input =
      """
      \n
      ##########################################################################
      #                                                                        #
      #                              !WARNING!                                 #
      #                                                                        #
      #      You're about to create production plans in Paddle. Multiple       #
      #      consecutive executions will create the same plans again.          #
      #      Please make sure to not leave duplicates behind!                  #
      #                                                                        #
      ##########################################################################

      * 'y' - proceed and create all plans
      * 't' - test only with two plans
      * 'h' - halt

      What would you like to do?
      """
      |> IO.gets()
      |> String.trim()
      |> String.upcase()

    test_run? =
      case user_input do
        "Y" ->
          IO.puts("Creating all plans...")
          false

        "T" ->
          IO.puts("Creating 2 plans just for testing. Make sure to delete them manually!")
          true

        _ ->
          IO.puts("Halting execution per user request.")
          System.halt()
      end

    {paddle_create_count, create_count} =
      if test_run? do
        {2, 1}
      else
        {length(to_be_created_in_paddle), length(input_plans)}
      end

    to_be_created_in_paddle
    |> Enum.take(paddle_create_count)
    |> Enum.each(&create_paddle_plan/1)

    IO.puts("⏳ waiting 3s before fetching the newly created plans...")
    Process.sleep(3000)
    IO.puts("Fetching the #{create_count} plans created a moment ago...")

    created_paddle_plans =
      fetch_all_prod_plans()
      |> Enum.sort_by(& &1["id"])
      |> Enum.take(-paddle_create_count)

    file_path_to_write = Path.join("priv", String.replace(filename, "input_", ""))

    prod_plans_with_ids_and_prices =
      input_plans
      |> Enum.take(create_count)
      |> write_prod_plans_json_file(file_path_to_write, created_paddle_plans)

    IO.puts("✅ Wrote #{create_count} new plans into #{file_path_to_write}!")

    if not test_run? do
      write_prices(prod_plans_with_ids_and_prices)
      IO.puts("✅ Updated `plan_prices.json`.")
    end

    IO.puts("✅ All done!")
  end

  defp create_paddle_plan(%{name: name, price: price, type: type, interval_index: interval_index}) do
    your_unique_token = "abc"

    # Replace this curl command. You should be able to reuse
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

  defp fetch_all_prod_plans() do
    "https://vendors.paddle.com/api/2.0/subscription/plans"
    |> fetch_all_paddle_plans(%{
      vendor_id: "REPLACE ME",
      vendor_auth_code: "REPLACE ME"
    })
  end

  @paddle_plans_api_pagination_limit 500
  def fetch_all_paddle_plans(url, paddle_credentials, page \\ 0, fetched \\ 0) do
    body =
      paddle_credentials
      |> Map.merge(%{
        limit: @paddle_plans_api_pagination_limit,
        offset: page * @paddle_plans_api_pagination_limit
      })
      |> JSON.encode!()

    headers = [
      {"Content-type", "application/json"},
      {"Accept", "application/json"}
    ]

    request = Finch.build(:post, url, headers, body)

    with {:ok, response} <- Finch.request(request, MyFinch),
         {:ok, %{"success" => true, "response" => plans} = body} <- JSON.decode(response.body) do
      fetched = body["count"] + fetched
      total = body["total"]

      IO.puts("✅ Successfully fetched #{fetched}/#{body["total"]} plans")

      if fetched == total do
        plans
      else
        plans ++ fetch_all_paddle_plans(url, paddle_credentials, page + 1, fetched)
      end
    else
      error ->
        IO.puts("❌ Failed to fetch plans from Paddle - #{inspect(error)}")
        System.halt(1)
    end
  end

  defp write_prod_plans_json_file(input_plans, filepath, paddle_plans) do
    prod_plans_with_prices =
      input_plans
      |> Enum.map(fn input_plan ->
        monthly_plan_name = plan_name(input_plan, "monthly")
        yearly_plan_name = plan_name(input_plan, "yearly")

        %{"id" => monthly_product_id} =
          Enum.find(paddle_plans, &(&1["name"] == monthly_plan_name))

        %{"id" => yearly_product_id} =
          Enum.find(paddle_plans, &(&1["name"] == yearly_plan_name))

        input_plan
        |> Map.merge(%{
          "monthly_product_id" => to_string(monthly_product_id),
          "yearly_product_id" => to_string(yearly_product_id)
        })
      end)

    content =
      prod_plans_with_prices
      |> Enum.map(fn plan ->
        plan
        |> Map.drop(["monthly_price", "yearly_price"])
        |> order_keys()
      end)
      |> Jason.encode!(pretty: true)

    File.write!(filepath, content)

    prod_plans_with_prices
  end

  @plan_prices_filepath Application.app_dir(:plausible, ["priv", "plan_prices.json"])
  defp write_prices(prod_plans_with_ids_and_prices) do
    current_prices = File.read!(@plan_prices_filepath) |> JSON.decode!()

    new_prices =
      prod_plans_with_ids_and_prices
      |> Enum.reduce(current_prices, fn plan, prices ->
        prices
        |> Map.put_new(plan["monthly_product_id"], plan["monthly_price"])
        |> Map.put_new(plan["yearly_product_id"], plan["yearly_price"])
      end)
      |> Enum.sort()
      |> Jason.OrderedObject.new()
      |> Jason.encode!(pretty: true)

    File.write(@plan_prices_filepath, new_prices)
  end

  @plan_key_order [
    "kind",
    "generation",
    "monthly_pageview_limit",
    "monthly_product_id",
    "yearly_product_id",
    "site_limit",
    "team_member_limit",
    "features"
  ]
  def order_keys(plan) do
    plan
    |> Map.to_list()
    |> Enum.sort_by(fn {key, _value} ->
      Enum.find_index(@plan_key_order, fn ordered_key -> ordered_key == key end) || 99
    end)
    |> Jason.OrderedObject.new()
  end

  defp plan_name(plan, type) do
    kind = plan["kind"] |> String.capitalize()
    type = type |> String.capitalize()

    volume =
      plan["monthly_pageview_limit"]
      |> PlausibleWeb.StatsView.large_number_format(capitalize_k?: true)

    [type, kind, volume] |> Enum.join("_")
    "Plausible #{kind} #{type} Plan (#{volume})"
  end

  def curl_quietly(cmd) do
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
