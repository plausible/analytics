defmodule Plausible.Billing.PaddleBilling.Api do
  @moduledoc """
  Paddle Billing API HTTP client.
  """

  alias Plausible.HTTPClient
  alias Plausible.HTTPClient.Non200Error

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
    type = Keyword.get(opts, :type, "standard")
    {amount, currency} = to_amount_currency(price)

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

    data = Keyword.get(opts, :custom_data, %{})

    params = %{
      product_id: product_id,
      type: type,
      description: description,
      unit_price: money(amount, currency),
      unit_price_overrides: overrides,
      billing_cycle: %{
        interval: interval,
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

      {:error, %Non200Error{reason: %Finch.Response{body: %{"error" => error}}}} ->
        {:error, error}

      {:error, error} ->
        {:error, error}

      unexpected ->
        {:error, unexpected}
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
        {amount, currency} = opts |> Keyword.fetch!(:price) |> to_amount_currency()

        # crash if base currency is other than the default
        @base_currency = currency

        Map.put(params, :unit_price_overrides, parity_overrides(amount))
      else
        params
      end

    if params != %{} do
      url =
        prices_url()
        |> URI.new!()
        |> URI.append_path("/" <> price_id)
        |> URI.to_string()

      case HTTPClient.impl().patch(url, req_headers(), params) do
        {:ok, %Finch.Response{body: %{"data" => data}, status: 200}} ->
          {:ok, data}

        {:error, %Non200Error{reason: %Finch.Response{body: %{"error" => error}}}} ->
          {:error, error}

        {:error, error} ->
          {:error, error}

        unexpected ->
          {:error, unexpected}
      end
    else
      {:error, :no_changes}
    end
  end

  defp to_amount_currency(price) do
    # 1 USD is "100".
    # Raises if the price has fractions of a cent.
    amount =
      price
      |> Money.to_decimal()
      |> Decimal.mult(100)
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
    type = Keyword.get(opts, :type, "standard")

    extra_data =
      if Keyword.get(opts, :enterprise?) do
        %{"enterprise" => true}
      else
        %{}
      end

    params = %{
      name: name,
      description: description,
      type: type,
      tax_category: "saas",
      custom_data: Map.merge(custom_data, extra_data)
    }

    case HTTPClient.impl().post(products_url(), req_headers(), params) do
      {:ok, %Finch.Response{body: %{"data" => data}, status: 201}} ->
        {:ok, data}

      {:error, %Non200Error{reason: %Finch.Response{body: %{"error" => error}}}} ->
        {:error, error}

      {:error, error} ->
        {:error, error}

      unexpected ->
        {:error, unexpected}
    end
  end

  @spec update_product(String.t(), Keyword.t()) :: {:ok, map()} | {:error, any()}
  def update_product(product_id, opts \\ []) do
    params =
      opts
      |> Keyword.take([:name, :description, :custom_data, :status])
      |> Map.new()

    params =
      if opts[:enterprise?] do
        Map.update(params, :custom_data, %{}, &Map.merge(&1, %{"enterprise" => true}))
      else
        params
      end

    if params != %{} do
      url =
        products_url()
        |> URI.new!()
        |> URI.append_path("/" <> product_id)
        |> URI.to_string()

      case HTTPClient.impl().patch(url, req_headers(), params) do
        {:ok, %Finch.Response{body: %{"data" => data}, status: 200}} ->
          {:ok, data}

        {:error, %Non200Error{reason: %Finch.Response{body: %{"error" => error}}}} ->
          {:error, error}

        {:error, error} ->
          {:error, error}

        unexpected ->
          {:error, unexpected}
      end
    else
      {:error, :no_changes}
    end
  end

  @spec list_products(:standard | :custom | :all) :: {:ok, [map()]} | {:error, any()}
  def list_products(type \\ :all) do
    if type == :all do
      with {:ok, standard_products} <- list_products(:standard),
           {:ok, custom_products} <- list_products(:custom) do
        {:ok, standard_products ++ custom_products}
      end
    else
      params = %{
        per_page: @products_page_size,
        include: "prices",
        type: type
      }

      url =
        products_url()
        |> URI.new!()
        |> URI.append_query(URI.encode_query(params))
        |> URI.to_string()

      list_products(url, [])
    end
  end

  defp list_products(next_url, acc) when is_binary(next_url) do
    case HTTPClient.impl().get(next_url, req_headers()) do
      {:ok, %Finch.Response{body: %{"data" => data, "meta" => meta}, status: 200}} ->
        if meta["pagination"]["has_more"] do
          list_products(meta["pagination"]["next"], acc ++ data)
        else
          {:ok, acc ++ data}
        end

      {:error, %Non200Error{reason: %Finch.Response{body: %{"error" => error}}}} ->
        {:error, error}

      {:error, error} ->
        {:error, error}

      unexpected ->
        {:error, unexpected}
    end
  end

  defp products_url() do
    Path.join(api_domain(), "/products")
  end

  defp prices_url() do
    Path.join(api_domain(), "/prices")
  end

  def api_domain() do
    "https://sandbox-api.paddle.com"
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
