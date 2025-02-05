defmodule Plausible.Auth.UserAdmin do
  use Plausible.Repo
  use Plausible

  def custom_index_query(_conn, _schema, query) do
    from(r in query, preload: [:owned_teams])
  end

  def custom_show_query(_conn, _schema, query) do
    from(u in query, preload: [:owned_teams])
  end

  def form_fields(_) do
    [
      name: nil,
      email: nil,
      previous_email: nil,
      notes: %{type: :textarea, rows: 6}
    ]
  end

  def delete(_conn, %{data: user}) do
    case Plausible.Auth.delete_user(user) do
      {:ok, :deleted} ->
        :ok

      {:error, :is_only_team_owner} ->
        "The user is the only public team owner on one or more teams."
    end
  end

  def index(_) do
    [
      name: nil,
      email: nil,
      owned_teams: %{value: &teams(&1.owned_teams)},
      inserted_at: %{name: "Created at", value: &format_date(&1.inserted_at)}
    ]
  end

  def resource_actions(_) do
    [
      reset_2fa: %{
        name: "Reset 2FA",
        action: fn _, user -> disable_2fa(user) end
      }
    ]
  end

  def disable_2fa(user) do
    Plausible.Auth.TOTP.force_disable(user)
  end

  defp teams([]) do
    "(none)"
  end

  defp teams(teams) do
    teams
    |> Enum.map_join("<br>\n", fn team ->
      """
      <a href="/crm/teams/team/#{team.id}">#{team.name}</a>
      """
    end)
    |> Phoenix.HTML.raw()
  end

  defp format_date(nil), do: "--"

  defp format_date(date) do
    Calendar.strftime(date, "%b %-d, %Y")
  end
end
