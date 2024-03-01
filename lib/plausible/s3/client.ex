defmodule Plausible.S3.Client do
  @moduledoc false
  @behaviour ExAws.Request.HttpClient

  @impl true
  def request(method, url, body, headers, opts) do
    req = Finch.build(method, url, headers, body)

    case Finch.request(req, Plausible.Finch, opts) do
      {:ok, %Finch.Response{status: status, headers: headers, body: body}} ->
        {:ok, %{status_code: status, headers: headers, body: body}}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end
end
