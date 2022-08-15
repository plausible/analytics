defmodule Plausible.HTTPClient do
  @moduledoc """
  HTTP Client built on top of Finch.
  """

  @doc """
  Make a POST request
  """
  def post(url, headers \\ [], params \\ nil) do
    call(:post, url, headers, params)
  end

  @doc """
  Make a GET request
  """
  def get(url, headers \\ [], params \\ nil) do
    call(:get, url, headers, params)
  end

  defp call(method, url, headers, params) do
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
end
