defmodule Plausible.Google.ApiTest do
  use Plausible.DataCase, async: true
  alias Plausible.Google.Api
  import Plausible.TestUtils
  import Double

  @ok_response Jason.encode!(%{
                 "reports" => [
                   %{
                     "data" => %{
                       "rows" => [
                         %{
                           "dimensions" => ["20220101"],
                           "metrics" => [%{"values" => ["1", "1", "1", "1", "1"]}]
                         }
                       ]
                     }
                   }
                 ]
               })

  @empty_response Jason.encode!(%{
                    "reports" => [%{"data" => %{"rows" => []}}]
                  })

  def start_buffer(_setup_args) do
    {:ok, pid} = Plausible.Google.Buffer.start_link()
    {:ok, buffer: pid}
  end

  describe "fetch_and_persist/4" do
    setup [:create_user, :create_new_site, :start_buffer]

    test "will fetch and persist import data from Google Analytics", %{site: site, buffer: buffer} do
      httpoison =
        HTTPoison
        |> stub(:post, fn _url, _body, _headers, _opts ->
          {:ok, %HTTPoison.Response{status_code: 200, body: @ok_response}}
        end)

      request = %Plausible.Google.ReportRequest{
        dataset: "imported_visitors",
        view_id: "123",
        date_range: Date.range(~D[2022-01-01], ~D[2022-02-01]),
        dimensions: ["ga:date"],
        metrics: ["ga:users"],
        access_token: "fake-token",
        page_token: nil,
        page_size: 10_000
      }

      Api.fetch_and_persist(site, request,
        http_client: httpoison,
        sleep_time: 0,
        buffer: buffer
      )

      Plausible.Google.Buffer.flush(buffer)
      assert imported_visitor_count(site) == 1
    end

    test "retries HTTP request up to 5 times before raising the last error", %{
      site: site,
      buffer: buffer
    } do
      httpoison =
        HTTPoison
        |> stub(:post, fn _url, _body, _headers, _opts ->
          {:error, %HTTPoison.Error{reason: :nxdomain}}
        end)
        |> stub(:post, fn _url, _body, _headers, _opts ->
          {:error, %HTTPoison.Error{reason: :timeout}}
        end)
        |> stub(:post, fn _url, _body, _headers, _opts ->
          {:error, %HTTPoison.Error{reason: :closed}}
        end)
        |> stub(:post, fn _url, _body, _headers, _opts ->
          {:ok, %HTTPoison.Response{status_code: 503}}
        end)
        |> stub(:post, fn _url, _body, _headers, _opts ->
          {:ok, %HTTPoison.Response{status_code: 502}}
        end)

      request = %Plausible.Google.ReportRequest{
        view_id: "123",
        date_range: Date.range(~D[2022-01-01], ~D[2022-02-01]),
        dimensions: ["ga:date"],
        metrics: ["ga:users"],
        access_token: "fake-token",
        page_token: nil,
        page_size: 10_000
      }

      assert_raise RuntimeError, "Google API request failed too many times", fn ->
        Api.fetch_and_persist(site, request,
          http_client: httpoison,
          sleep_time: 0,
          buffer: buffer
        )
      end

      assert_receive({HTTPoison, :post, [_, _, _, _]})
      assert_receive({HTTPoison, :post, [_, _, _, _]})
      assert_receive({HTTPoison, :post, [_, _, _, _]})
      assert_receive({HTTPoison, :post, [_, _, _, _]})
      assert_receive({HTTPoison, :post, [_, _, _, _]})
    end

    test "retries HTTP request if the rows are empty", %{site: site, buffer: buffer} do
      httpoison =
        HTTPoison
        |> stub(:post, fn _url, _body, _headers, _opts ->
          {:ok, %HTTPoison.Response{status_code: 200, body: @empty_response}}
        end)
        |> stub(:post, fn _url, _body, _headers, _opts ->
          {:ok, %HTTPoison.Response{status_code: 200, body: @ok_response}}
        end)

      request = %Plausible.Google.ReportRequest{
        dataset: "imported_visitors",
        view_id: "123",
        date_range: Date.range(~D[2022-01-01], ~D[2022-02-01]),
        dimensions: ["ga:date"],
        metrics: ["ga:users"],
        access_token: "fake-token",
        page_token: nil,
        page_size: 10_000
      }

      Api.fetch_and_persist(site, request,
        http_client: httpoison,
        sleep_time: 0,
        buffer: buffer
      )

      assert_receive({HTTPoison, :post, [_, _, _, _]})
      assert_receive({HTTPoison, :post, [_, _, _, _]})

      Plausible.Google.Buffer.flush(buffer)
      assert imported_visitor_count(site) == 1
    end
  end

  defp imported_visitor_count(site) do
    Plausible.ClickhouseRepo.one(
      from iv in "imported_visitors",
        where: iv.site_id == ^site.id,
        select: sum(iv.visitors)
    )
  end
end
