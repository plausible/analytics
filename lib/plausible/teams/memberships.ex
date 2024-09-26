defmodule Plausible.Teams.Memberships do
  @moduledoc false

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Repo

  def team_role(team, user) do
    result =
      from(u in Auth.User,
        inner_join: tm in assoc(u, :team_memberships),
        where: tm.team_id == ^team.id and tm.user_id == ^user.id,
        select: tm.role
      )
      |> Repo.one()

    case result do
      nil -> {:error, :not_a_member}
      role -> {:ok, role}
    end
  end

  def site_role(site, user) do
    result =
      from(u in Auth.User,
        inner_join: tm in assoc(u, :team_memberships),
        left_join: gm in assoc(tm, :guest_memberships),
        where: tm.team_id == ^site.team_id and tm.user_id == ^user.id,
        where: tm.role != :guest or gm.site_id == ^site.id,
        select: {tm.role, gm.role}
      )
      |> Repo.one()

    case result do
      {:guest, role} -> role
      {role, _} -> role
      _ -> nil
    end
  end
end
