defmodule Plausible.TestUtils do
  alias Plausible.Auth

  def create_user(_) do
    {:ok, user} = Auth.create_user("Jane Doe", "user@example.com")
    {:ok, user: user}
  end

  def log_in(%{user: user, conn: conn}) do
    opts =
      Plug.Session.init(
        store: :cookie,
        key: "foobar",
        encryption_salt: "encrypted cookie salt",
        signing_salt: "signing salt",
        log: false,
        encrypt: false
      )

    conn =
      conn
      |> Plug.Session.call(opts)
      |> Plug.Conn.fetch_session()
      |> Plug.Conn.put_session(:current_user_email, user.email)

    {:ok, conn: conn}
  end
end
