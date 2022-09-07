defmodule Plausible.HTTPClient do
  @moduledoc """
  HTTP Client built on top of Finch.

  By default, request parameters are json-encoded.

  If a raw binary value is supplied, no encoding is performed.
  If x-www-form-urlencoded content-type is set in headers, 
  URL encoding is invoked.
  """

  @type url() :: Finch.Request.url()
  @type headers() :: Finch.Request.headers()
  @type params() :: Finch.Request.body() | map()
  @type response() :: {:ok, Finch.Response.t()} | {:error, Mint.Types.error() | Finch.Error.t()}

  @doc """
  Make a POST request
  """
  @spec post(url(), headers(), params()) :: response()
  def(post(url, headers \\ [], params \\ nil)) do
    call(:post, url, headers, params)
  end

  @doc """
  Make a GET request
  """
  @spec get(url(), headers()) :: response()
  def get(url, headers \\ []) do
    call(:get, url, headers, nil)
  end

  defp call(method, url, headers, params) do
    {params, headers} = maybe_encode_params(params, headers)

    method
    |> build_request(url, headers, params)
    |> do_request
  end

  defp build_request(method, url, headers, params) do
    Finch.build(method, url, headers, params)
  end

  defp do_request(request) do
    Finch.request(request, Plausible.Finch)
  end

  defp maybe_encode_params(params, headers) when is_binary(params) or is_nil(params) do
    {params, headers}
  end

  defp maybe_encode_params(params, headers) when is_map(params) do
    content_type =
      Enum.find_value(headers, "", fn {k, v} ->
        if String.downcase(k) == "content-type" do
          v
        end
      end)

    case String.downcase(content_type) do
      "application/x-www-form-urlencoded" ->
        {URI.encode_query(params), headers}

      "application/json" ->
        {Jason.encode!(params), headers}

      _ ->
        {Jason.encode!(params), [{"content-type", "application/json"} | headers]}
    end
  end
end
