defmodule Plausible.Teams.Adapter.Read.Sites do
  @moduledoc """
  Transition adapter for new schema reads
  """

  import Ecto.Query

  alias Plausible.Repo
  alias Plausible.Site
  use Plausible.Teams.Adapter

  def list(user, pagination_params, opts \\ []) do
    switch(
      user,
      team_fn: fn _ -> Plausible.Teams.Sites.list(user, pagination_params, opts) end,
      user_fn: fn _ -> old_list(user, pagination_params, opts) end
    )
  end

  def list_with_invitations(user, pagination_params, opts \\ []) do
    switch(
      user,
      team_fn: fn _ ->
        Plausible.Teams.Sites.list_with_invitations(user, pagination_params, opts)
      end,
      user_fn: fn _ -> old_list_with_invitations(user, pagination_params, opts) end
    )
  end

  defp old_list(user, pagination_params, opts) do
    domain_filter = Keyword.get(opts, :filter_by_domain)

    from(s in Site,
      left_join: up in Site.UserPreference,
      on: up.site_id == s.id and up.user_id == ^user.id,
      inner_join: sm in assoc(s, :memberships),
      on: sm.user_id == ^user.id,
      select: %{
        s
        | pinned_at: selected_as(up.pinned_at, :pinned_at),
          entry_type:
            selected_as(
              fragment(
                """
                CASE
                WHEN ? IS NOT NULL THEN 'pinned_site'
                ELSE 'site'
                END
                """,
                up.pinned_at
              ),
              :entry_type
            )
      },
      order_by: [asc: selected_as(:entry_type), desc: selected_as(:pinned_at), asc: s.domain],
      preload: [memberships: sm]
    )
    |> maybe_filter_by_domain(domain_filter)
    |> Repo.paginate(pagination_params)
  end

  defp old_list_with_invitations(user, pagination_params, opts) do
    domain_filter = Keyword.get(opts, :filter_by_domain)

    result =
      from(s in Site,
        left_join: up in Site.UserPreference,
        on: up.site_id == s.id and up.user_id == ^user.id,
        left_join: i in assoc(s, :invitations),
        on: i.email == ^user.email,
        left_join: sm in assoc(s, :memberships),
        on: sm.user_id == ^user.id,
        where: not is_nil(sm.id) or not is_nil(i.id),
        select: %{
          s
          | pinned_at: selected_as(up.pinned_at, :pinned_at),
            entry_type:
              selected_as(
                fragment(
                  """
                  CASE
                  WHEN ? IS NOT NULL THEN 'invitation'
                  WHEN ? IS NOT NULL THEN 'pinned_site'
                  ELSE 'site'
                  END
                  """,
                  i.id,
                  up.pinned_at
                ),
                :entry_type
              )
        },
        order_by: [asc: selected_as(:entry_type), desc: selected_as(:pinned_at), asc: s.domain],
        preload: [memberships: sm, invitations: i]
      )
      |> maybe_filter_by_domain(domain_filter)
      |> Repo.paginate(pagination_params)

    # Populating `site` preload on `invitation`
    # without requesting it from database.
    # Necessary for invitation modals logic.
    entries =
      Enum.map(result.entries, fn
        %{invitations: [invitation]} = site ->
          site = %{site | invitations: [], memberships: []}
          invitation = %{invitation | site: site}
          %{site | invitations: [invitation]}

        site ->
          site
      end)

    %{result | entries: entries}
  end

  def list_people(site, user) do
    if Plausible.Teams.read_team_schemas?(user) do
      owner_membership =
        from(
          tm in Teams.Membership,
          where: tm.team_id == ^site.team_id,
          where: tm.role == :owner,
          select: %Plausible.Site.Membership{
            user_id: tm.user_id,
            role: tm.role
          }
        )
        |> Repo.one!()

      memberships =
        from(
          gm in Teams.GuestMembership,
          inner_join: tm in assoc(gm, :team_membership),
          where: gm.site_id == ^site.id,
          select: %Plausible.Site.Membership{
            user_id: tm.user_id,
            role:
              fragment(
                """
                CASE
                WHEN ? = 'editor' THEN 'admin'
                ELSE ?
                END
                """,
                gm.role,
                gm.role
              )
          }
        )
        |> Repo.all()

      memberships = Repo.preload([owner_membership | memberships], :user)

      invitations =
        from(
          gi in Teams.GuestInvitation,
          inner_join: ti in assoc(gi, :team_invitation),
          where: gi.site_id == ^site.id,
          select: %Plausible.Auth.Invitation{
            invitation_id: gi.invitation_id,
            email: ti.email,
            role:
              fragment(
                """
                CASE
                WHEN ? = 'editor' THEN 'admin'
                ELSE ?
                END
                """,
                gi.role,
                gi.role
              )
          }
        )
        |> Repo.all()

      %{memberships: memberships, invitations: invitations}
    else
      site
      |> Repo.preload([:invitations, memberships: :user])
      |> Map.take([:memberships, :invitations])
    end
  end

  defp maybe_filter_by_domain(query, domain)
       when byte_size(domain) >= 1 and byte_size(domain) <= 64 do
    where(query, [s], ilike(s.domain, ^"%#{domain}%"))
  end

  defp maybe_filter_by_domain(query, _), do: query
end
