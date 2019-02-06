defmodule Plausible.TestUtils do
  alias Plausible.Auth
  use Plausible.Repo

  def create_user(_) do
    {:ok, user} = Auth.create_user("Jane Doe", "user@example.com")
    {:ok, user: user}
  end

  def create_site(%{user: user}) do
    site = Plausible.Site.changeset(%Plausible.Site{}, %{
      domain: "example.com",
      timezone: "UTC"
    }) |> Repo.insert!
    Plausible.Site.Membership.changeset(%Plausible.Site.Membership{}, %{site_id: site.id, user_id: user.id}) |> Repo.insert!
    {:ok, site: site}
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
      |> Plug.Conn.put_session(:current_user_id, user.id)

    {:ok, conn: conn}
  end
end
