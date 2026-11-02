defmodule Plausible.Billing.PaddleBilling.Api do
  @moduledoc """
  Paddle Billing API HTTP client.
  """

  alias Plausible.HTTPClient

  @headers [
    {"content-type", "application/json"},
    {"accept", "application/json"}
  ]

  @products_page_size 200

  @eurozone ~w(AT BE BG HR CY EE FI FR DE GR IE IT LV LT LU MT NL PT SK SI ES)

  @base_currency :USD

  @spec create_price(String.t(), String.t(), Keyword.t()) :: {:ok, map()} | {:error, any()}
  def create_price(product_id, description, opts) do
    price = Keyword.fetch!(opts, :price)
    {amount, currency} = to_amount_currency(price)

    type =
      if Keyword.get(opts, :enterprise?) do
        "custom"
      else
        "standard"
      end

    interval =
      case Keyword.fetch!(opts, :interval) do
        :yearly -> "year"
        :monthly -> "month"
      end

    overrides =
      if Keyword.get(opts, :overrides?) do
        # crash if base currency is other than the default
        @base_currency = currency

        parity_overrides(amount)
      else
        []
      end

    tax_mode = Keyword.get(opts, :tax_mode, :account_setting)

    data = Keyword.get(opts, :data, %{})

    params = %{
      product_id: product_id,
      type: type,
      description: description,
      unit_price: money(amount, currency),
      unit_price_overrrides: overrides,
      billing_cycle: %{
        internval: interval,
        frequency: 1
      },
      quantity: %{
        minimum: 1,
        maximum: 1
      },
      tax_mode: tax_mode,
      custom_data: data
    }

    case HTTPClient.impl().post(prices_url(), req_headers(), params) do
      {:ok, %Finch.Response{body: %{"data" => data}, status: 201}} ->
        {:ok, data}

      {:error, %Finch.Response{body: %{"error" => error}}} ->
        {:error, error}

      error ->
        {:error, error}
    end
  end

  @spec update_price(String.t(), Keyword.t()) :: {:ok, map()} | {:error, any()}
  def update_price(price_id, opts \\ []) do
    params =
      opts
      |> Keyword.take([:description, :status, :tax_mode, :custom_data])
      |> Map.new()

    params =
      if price = opts[:price] do
        {amount, currency} = to_amount_currency(price)

        Map.put(params, :unit_price, money(amount, currency))
      else
        params
      end

    params =
      if opts[:overrides?] do
        # Will crash if overrides weren't updated along with the price
        amount = Map.fetch!(params, :amount)

        Map.put(params, :unit_price_overrides, parity_overrides(amount))
      else
        params
      end

    if params != %{} do
      url =
        prices_url()
        |> URI.new!()
        |> URI.append_path(price_id)
        |> URI.to_string()

      case HTTPClient.impl().patch(url, req_headers(), params) do
        {:ok, %Finch.Response{body: %{"data" => data}, status: 200}} ->
          {:ok, data}

        {:error, %Finch.Response{body: %{"error" => error}}} ->
          {:error, error}

        error ->
          {:error, error}
      end
    else
      {:error, :no_changes}
    end
  end

  defp to_amount_currency(price) do
    amount =
      price
      |> Money.to_decimal()
      |> Keyword.fetch!(:amount)
      |> Decimal.mult(1000)
      |> Decimal.to_integer()

    currency = Money.to_currency_code(price)

    {amount, currency}
  end

  defp parity_overrides(amount) do
    [
      %{country_codes: @eurozone, unit_price: money(amount, "EUR")},
      %{country_codes: ["GB"], unit_price: money(amount, "GBP")}
    ]
  end

  defp money(amount, currency) do
    %{amount: Integer.to_string(amount), currency_code: currency}
  end

  @spec create_product(String.t(), map(), Keyword.t()) :: {:ok, map()} | {:error, any()}
  def create_product(name, custom_data, opts \\ []) do
    description = Keyword.get(opts, :description)

    type =
      if Keyword.get(opts, :enterprise?) do
        "custom"
      else
        "standard"
      end

    params = %{
      name: name,
      description: description,
      type: type,
      tax_category: "saas",
      custom_data: custom_data
    }

    case HTTPClient.impl().post(products_url(), req_headers(), params) do
      {:ok, %Finch.Response{body: %{"data" => data}, status: 201}} ->
        {:ok, data}

      {:error, %Finch.Response{body: %{"error" => error}}} ->
        {:error, error}

      error ->
        {:error, error}
    end
  end

  @spec update_product(String.t(), Keyword.t()) :: {:ok, map()} | {:error, any()}
  def update_product(product_id, opts \\ []) do
    params =
      opts
      |> Keyword.take([:name, :description, :custom_data, :status])
      |> Map.new()

    if params != %{} do
      url =
        products_url()
        |> URI.new!()
        |> URI.append_path(product_id)
        |> URI.to_string()

      case HTTPClient.impl().patch(url, req_headers(), params) do
        {:ok, %Finch.Response{body: %{"data" => data}, status: 200}} ->
          {:ok, data}

        {:error, %Finch.Response{body: %{"error" => error}}} ->
          {:error, error}

        error ->
          {:error, error}
      end
    else
      {:error, :no_changes}
    end
  end

  @spec list_products() :: [map()]
  def list_products() do
    params = %{
      per_page: @products_page_size,
      include: "prices"
    }

    url =
      products_url()
      |> URI.new!()
      |> URI.append_query(URI.encode_query(params))
      |> URI.to_string()

    list_products(url, [])
  end

  defp list_products(next_url, acc) when is_binary(next_url) do
    case HTTPClient.impl().get(next_url, req_headers()) do
      {:ok, %Finch.Response{body: %{"data" => data, "meta" => meta}, status: 200}} ->
        if meta["pagination"]["has_more"] do
          list_products(meta["pagination"]["next"], acc ++ data)
        else
          {:ok, acc ++ data}
        end

      {:error, %Finch.Response{body: %{"error" => error}}} ->
        {:error, error}

      error ->
        {:error, error}
    end
  end

  defp products_url() do
    Path.join(api_domain(), "/products")
  end

  defp prices_url() do
    Path.join(api_domain(), "/prices")
  end

  def api_domain() do
    if Application.get_env(:plausible, :environment) == "prod" do
      "https://api.paddle.com"
    else
      "https://sandbox-api.paddle.com"
    end
  end

  defp req_headers() do
    config = get_config()
    api_key = Keyword.fetch!(config, :api_key)

    [{"authorization", "Bearer #{api_key}"} | @headers]
  end

  defp get_config() do
    Application.get_env(:plausible, :paddle_billing)
  end
end
