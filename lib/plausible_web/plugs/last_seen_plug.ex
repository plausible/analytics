defmodule PlausibleWeb.LastSeenPlug do
  import Plug.Conn
  use Plausible.Repo

  @one_hour 60 * 60

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    last_seen = get_session(conn, :last_seen)
    user = conn.assigns[:current_user]

    cond do
      user && last_seen && last_seen < unix_now() - @one_hour ->
        persist_last_seen(user)
        put_session(conn, :last_seen, unix_now())

      user && !last_seen ->
        put_session(conn, :last_seen, unix_now())

      true ->
        conn
    end
  end

  defp persist_last_seen(user) do
    q = from(u in Plausible.Auth.User, where: u.id == ^user.id)

    Repo.update_all(q, set: [last_seen: DateTime.utc_now()])
  end

  defp unix_now do
    DateTime.utc_now() |> DateTime.to_unix()
  end
end
