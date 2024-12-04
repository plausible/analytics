defmodule Plausible.Teams.Adapter.Read.Sites do
  @moduledoc """
  Transition adapter for new schema reads
  """

  use Plausible.Teams.Adapter

  import Ecto.Query

  alias Plausible.Repo

  def get_for_user!(user, domain, roles \\ [:owner, :admin, :viewer]) do
    {query_fn, roles} = for_user_query_and_roles(user, roles)

    site =
      if :super_admin in roles and Plausible.Auth.is_super_admin?(user.id) do
        Plausible.Sites.get_by_domain!(domain)
      else
        user.id
        |> query_fn.(domain, List.delete(roles, :super_admin))
        |> Repo.one!()
      end

    Repo.preload(site, :team)
  end

  def get_for_user(user, domain, roles \\ [:owner, :admin, :viewer]) do
    {query_fn, roles} = for_user_query_and_roles(user, roles)

    if :super_admin in roles and Plausible.Auth.is_super_admin?(user.id) do
      Plausible.Sites.get_by_domain(domain)
    else
      user.id
      |> query_fn.(domain, List.delete(roles, :super_admin))
      |> Repo.one()
    end
  end

  defp for_user_query_and_roles(user, roles) do
    switch(
      user,
      team_fn: fn _ ->
        translated_roles =
          Enum.map(roles, fn
            :admin -> :editor
            other -> other
          end)

        {&new_get_for_user_query/3, translated_roles}
      end,
      user_fn: fn _ ->
        {&old_get_for_user_query/3, roles}
      end
    )
  end

  defp old_get_for_user_query(user_id, domain, roles) do
    from(s in Plausible.Site,
      join: sm in Plausible.Site.Membership,
      on: sm.site_id == s.id,
      where: sm.user_id == ^user_id,
      where: sm.role in ^roles,
      where: s.domain == ^domain or s.domain_changed_from == ^domain,
      select: s
    )
  end

  defp new_get_for_user_query(user_id, domain, roles) do
    roles = Enum.map(roles, &to_string/1)

    from(s in Plausible.Site,
      join: t in assoc(s, :team),
      join: tm in assoc(t, :team_memberships),
      left_join: gm in assoc(tm, :guest_memberships),
      where: tm.user_id == ^user_id,
      where: coalesce(gm.role, tm.role) in ^roles,
      where: s.domain == ^domain or s.domain_changed_from == ^domain,
      where: is_nil(gm.id) or gm.site_id == s.id,
      select: s
    )
  end
end
