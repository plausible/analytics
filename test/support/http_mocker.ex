defmodule Plausible.Test.Support.HTTPMocker do
  @moduledoc """
  Currently only supports post request, it's a drop-in replacement
  for our exvcr usage that wasn't ever needed (e.g. we had no way to
  re-record the cassettes anyway).
  """
  defmacro __using__(_) do
    quote do
      import Mox

      def mock_http_with(http_mock_fixture) do
        mocks =
          "fixture/http_mocks/#{http_mock_fixture}"
          |> File.read!()
          |> Jason.decode!()
          |> Enum.into(%{}, &{{&1["url"], &1["request_body"]}, &1})

        stub(
          Plausible.HTTPClient.Mock,
          :post,
          fn url, _, params, _ -> http_mocker_stub(mocks, url, params) end
        )

        stub(
          Plausible.HTTPClient.Mock,
          :post,
          fn url, _, params -> http_mocker_stub(mocks, url, params) end
        )
      end

      defp http_mocker_stub(mocks, url, params) do
        params =
          case Jason.encode(params) do
            {:ok, p} -> Jason.decode!(p)
            {:error, _} -> params
          end

        mock = Map.fetch!(mocks, {url, params})

        response = %Finch.Response{
          status: mock["status"],
          headers: [{"content-type", "application/json"}],
          body: mock["response_body"]
        }

        if mock["status"] >= 200 and mock["status"] < 300 do
          {:ok, response}
        else
          {:error, Plausible.HTTPClient.Non200Error.new(response)}
        end
      end
    end
  end
end
