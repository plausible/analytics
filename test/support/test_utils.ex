defmodule Plausible.TestUtils do
  use Plausible.Repo
  alias Plausible.Factory

  def create_user(_) do
    {:ok, user: Factory.insert(:user)}
  end

  def create_site(%{user: user}) do
    site = Factory.insert(:site, members: [user])
    {:ok, site: site}
  end

  def log_in(%{user: user, conn: conn}) do
    conn = init_session(conn)
    |> Plug.Conn.put_session(:current_user_id, user.id)

    {:ok, conn: conn}
  end

  def init_session(conn) do
    opts =
      Plug.Session.init(
        store: :cookie,
        key: "foobar",
        encryption_salt: "encrypted cookie salt",
        signing_salt: "signing salt",
        log: false,
        encrypt: false
      )

    conn
      |> Plug.Session.call(opts)
      |> Plug.Conn.fetch_session()
  end
end
