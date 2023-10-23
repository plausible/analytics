defmodule Plausible.Test.Support.HTTPMocker do
  import Mox

  def stub_with(http_mock_fixture) do
    mocks =
      "fixture/http_mocks/#{http_mock_fixture}"
      |> File.read!()
      |> Jason.decode!()
      |> Enum.into(%{}, &{{&1["url"], &1["request_body"]}, &1})

    stub(
      Plausible.HTTPClient.Mock,
      :post,
      fn url, _, params ->
        params = sanitize(params)
        mock = Map.fetch!(mocks, {url, params})

        {:ok,
         %Finch.Response{
           status: 200,
           headers: [{"content-type", "application/json"}],
           body: mock["response_body"]
         }}
      end
    )
  end

  defp sanitize(params) do
    case Jason.encode(params) do
      {:ok, p} -> Jason.decode!(p)
      {:error, _} -> params
    end
  end
end
