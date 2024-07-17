defmodule PlausibleWeb.HelpScoutController do
  use PlausibleWeb, :controller

  alias Plausible.HelpScout

  def callback(conn, %{"customer-id" => customer_id}) do
    conn =
      conn
      |> delete_resp_header("x-frame-options")
      |> put_layout(false)

    with :ok <- HelpScout.validate_signature(conn),
         {:ok, details} <- HelpScout.get_customer_details(customer_id) do
      render(conn, "callback.html", details)
    else
      {:error, error} ->
        render(conn, "callback.html", error: inspect(error))
    end
  end
end
