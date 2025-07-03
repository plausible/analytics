defmodule PlausibleWeb.Api.PaddleControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo

  import Mox
  setup :verify_on_exit!

  @webhook_body %{
    "alert_id" => "16173800",
    "alert_name" => "subscription_created",
    "cancel_url" =>
      "https://checkout.paddle.com/subscription/cancel?user=1032746&subscription=1869424&hash=eyJpdiI6Ik5XSnhkT1k2RSticStZcEVYZ2FEeTVZTHVSaTNpcFM4XC9aMFJNSjh6TFNrPSIsInZhbHVlIjoiWTMzd3dENGQySTc0UjVPM0U3dzVDUWlBMEQ3dGVzM2lyODRPczBVcjdBRXlncmQzRUVmQjhnZVhpTzJIRjFtNW41MmZOVmJNVUJ4empmeXgyUno1Z3c9PSIsIm1hYyI6ImFjNDMyNDIxNmNmMWNiNmViMmFlNGVkMzQ3ZjYyYTQ5ZWI2YTEyMDQ4YjFhNTEyMjAxNzNlNjEwOWU4OTVhOWMifQ%3D%3D",
    "checkout_id" => "38111668-chre6449b9c3cc8-f473e48a86",
    "currency" => "USD",
    "email" => "josh@joshuae.com",
    "event_time" => "2019-08-20 21:44:54",
    "marketing_consent" => 0,
    "next_bill_date" => "2019-09-20",
    "passthrough" => "235",
    "quantity" => "1",
    "status" => "active",
    "subscription_id" => "1869424",
    "subscription_plan_id" => "558018",
    "unit_price" => "6.00",
    "update_url" =>
      "https://checkout.paddle.com/subscription/update?user=1032746&subscription=1869424&hash=eyJpdiI6IkNUS2VZQlRxcFA5MVlEXC9Oa1ZwRDBNaGN4VVwvaU1RU2srWXc0bU1tQndyTT0iLCJ2YWx1ZSI6ImtTeU1ESkxWcEVrTDFmKzkyZ0FaSFo2Q0VNK3A2XC9NdEU4S2tGVFE2blJicGxBQzZ1XC9mMG1PcUo3MWV2OGY4YURjT1UxY2hpeHh5SFhlMmhXaFpoalE9PSIsIm1hYyI6ImZkNGU5MTg3YzQxZWYxNDJjNDkyMWFkYmZhZjIyMGQ3ZGI2YTVmMTcxZGViY2VkNzI0ZjNlMDRkZTgwNTEwMzUifQ%3D%3D",
    "user_id" => "1032746",
    "p_signature" =>
      "qfqKA3dI9d60uie9IORcvkHYV+rd1UaCu/f5kh4miTkeIQNimgusQG8pS1OHobCvN/OktwKCjFcbIwoa4nakOOWGroHJ8FjLJHBK4g1uI37Bp6l73dNl8mB4dNGW1M+atkz7ag6pETRIdEKCmC5tV9afN5CvbcqRV1lsj/x2fAsjAe/sQkmAP1jbDXOMEuHqkWssSB7Q+NGHHLHuNQ67m7YFBnZSgYzLeLMEApkZClJn0j6MokUVjW37ISn5eA5FlUbT7s6Kph54roRzLIpYvC+ff/n6ae2Iu1OsORxRBg4Uv8dqqjqBKXlv84/OB80U89yMIbRw/pbHD6+zF4FxgNV7nk2bjgK2V6h55AOuhJHHUMb4XX9R8i8iG1FOlNJaTwbhkIkvQF3q7nEItKCqizn+l4tFQ9MUcrjw8jytDznbOnSlmNhtcDVlnvXNDaSPkEA7AyR6c+BiZV/Y6I3y8sr8h/F/cBM3OPTwfdKK34jyWW4LRn15nSxq2kjH3SyLPEpTJUMdcRGAgBZc06E4lENU2x22E/JKG5BRi1aDs5OFQtrjYi2hOTI0dyPF3OLNeZcCgBCKBmKq5XIf1T0RPFWAWtKkzXhl/QH+4feNATb9/i6k5xKeUJf0ltWzsI5x84kvsC/m05hn/AuBDmcZGkVnDLXrqttR+zDXY6P1euE="
  }

  describe "webhook verification" do
    test "is verified when signature is correct", %{conn: conn} do
      new_user(id: 235)

      # NOTE: signature check happens sooner
      assert_raise RuntimeError, ~r/Invalid passthrough sent via Paddle/, fn ->
        post(conn, Routes.paddle_path(conn, :webhook), @webhook_body)
      end
    end

    test "not verified when signature is corrupted", %{conn: conn} do
      corrupted = Map.put(@webhook_body, "p_signature", Base.encode64("123 fake signature"))
      conn = post(conn, Routes.paddle_path(conn, :webhook), corrupted)
      assert conn.status == 400
    end
  end

  describe "fetching currency" do
    test "retrieves successfully", %{conn: conn} do
      expect_get_prices_response(get_prices_body("USD"))

      conn = get(conn, Routes.paddle_path(conn, :currency))
      assert_receive :paddle_queried
      assert json_response(conn, 200) == %{"currency" => "$"}
    end

    test "caches per ip", %{conn: initial_conn} do
      expect_get_prices_response(get_prices_body("USD"))

      conn = get(initial_conn, Routes.paddle_path(initial_conn, :currency))
      assert json_response(conn, 200) == %{"currency" => "$"}
      assert_receive :paddle_queried

      expect_get_prices_response(get_prices_body("GBP"))

      conn = get(initial_conn, Routes.paddle_path(initial_conn, :currency))
      assert json_response(conn, 200) == %{"currency" => "$"}
      refute_receive :paddle_queried

      new_ip =
        Plug.Conn.put_req_header(initial_conn, "x-forwarded-for", Plausible.TestUtils.random_ip())

      conn = get(new_ip, Routes.paddle_path(initial_conn, :currency))
      assert json_response(conn, 200) == %{"currency" => "£"}
      assert_receive :paddle_queried
    end

    test "falls back to EUR when paddle fails to respond", %{conn: conn} do
      expect_get_prices_response(%{"response" => %{}})

      conn = get(conn, Routes.paddle_path(conn, :currency))
      assert_receive :paddle_queried
      assert json_response(conn, 200) == %{"currency" => "€"}
    end

    test "does not cache failed fetches", %{conn: initial_conn} do
      expect_get_prices_response(%{"response" => %{}})

      conn = get(initial_conn, Routes.paddle_path(initial_conn, :currency))
      assert json_response(conn, 200) == %{"currency" => "€"}

      expect_get_prices_response(get_prices_body("USD"))

      conn = get(initial_conn, Routes.paddle_path(initial_conn, :currency))
      assert json_response(conn, 200) == %{"currency" => "$"}
    end

    defp expect_get_prices_response(body) do
      test = self()

      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn "https://checkout.paddle.com/api/2.0/prices",
           _,
           %{customer_ip: _customer_ip, product_ids: "857097"} ->
          send(test, :paddle_queried)

          {:ok,
           %Finch.Response{
             status: 200,
             headers: [{"content-type", "application/json"}],
             body: body
           }}
        end
      )
    end

    defp get_prices_body(currency) do
      %{
        "response" => %{
          "customer_country" => "PL",
          "products" => [
            %{
              "applied_coupon" => [],
              "currency" => currency,
              "list_price" => %{"gross" => 49.0, "net" => 49.0, "tax" => 0.0},
              "price" => %{"gross" => 49.0, "net" => 49.0, "tax" => 0.0},
              "product_id" => 857_097,
              "product_title" => "random",
              "subscription" => %{
                "frequency" => 1,
                "interval" => "month",
                "list_price" => %{"gross" => 49.0, "net" => 49.0, "tax" => 0.0},
                "price" => %{"gross" => 49.0, "net" => 49.0, "tax" => 0.0},
                "trial_days" => 0
              },
              "vendor_set_prices_included_tax" => false
            }
          ]
        },
        "success" => true
      }
    end
  end
end
