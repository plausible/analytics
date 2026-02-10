defmodule Plausible.Teams.Sites do
  @moduledoc false
  @sample_threshold 10_000_000

  import Ecto.Query
  use Plausible.Stats.SQL.Fragments

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Teams

  def list_with_clickhouse(user, team) do
    utc_start = ~N[2026-01-01 00:00:00]
    utc_end = ~N[2026-01-31 23:59:59]

    all_query =
      if Teams.setup?(team) do
        from(tm in Teams.Membership,
          inner_join: t in assoc(tm, :team),
          inner_join: s in assoc(t, :sites),
          where: tm.user_id == ^user.id and tm.role != :guest,
          where: tm.team_id == ^team.id,
          select: struct(s, [:id, :domain])
        )
      else
        my_team_query =
          from(tm in Teams.Membership,
            inner_join: t in assoc(tm, :team),
            inner_join: s in assoc(t, :sites),
            where: tm.user_id == ^user.id and tm.role != :guest,
            where: tm.is_autocreated,
            where: not t.setup_complete,
            select: struct(s, [:id, :domain])
          )

        guest_membership_query =
          from(tm in Teams.Membership,
            inner_join: gm in assoc(tm, :guest_memberships),
            inner_join: s in assoc(gm, :site),
            where: tm.user_id == ^user.id and tm.role == :guest,
            select: struct(s, [:id, :domain])
          )

        from(s in my_team_query,
          union_all: ^guest_membership_query
        )
      end

    clickhouse_query =
      from(e in Plausible.ClickhouseEventV2,
        hints: unsafe_fragment(^"SAMPLE #{@sample_threshold}"),
        right_join: sites in subquery(all_query, prefix: "postgres_remote"),
        on: fragment("CAST(?, 'UInt64')", sites.id) == e.site_id,
        select: %{
          site_id: sites.id,
          domain: sites.domain,
          visitors:
            selected_as(
              scale_sample(fragment("uniqIf(?, ? != 0)", e.user_id, e.site_id)),
              :visitors
            )
        },
        where: e.site_id == 0 or (e.timestamp >= ^utc_start and e.timestamp <= ^utc_end),
        group_by: [sites.id, sites.domain],
        order_by: [desc: selected_as(:visitors)]
      )

    clickhouse_query |> dbg()

    sites_by_traffic = Plausible.ClickhouseRepo.paginate(clickhouse_query, %{})
  end

  @type list_opt() :: {:filter_by_domain, String.t()} | {:team, Teams.Team.t() | nil}

  @role_type Plausible.Teams.Invitation.__schema__(:type, :role)

  @spec list(Auth.User.t(), map(), [list_opt()]) :: Scrivener.Page.t()
  def list(user, pagination_params, opts \\ []) do
    domain_filter = Keyword.get(opts, :filter_by_domain)
    team = Keyword.get(opts, :team)

    all_query =
      if Teams.setup?(team) do
        from(tm in Teams.Membership,
          inner_join: t in assoc(tm, :team),
          inner_join: s in assoc(t, :sites),
          where: tm.user_id == ^user.id and tm.role != :guest,
          where: tm.team_id == ^team.id,
          select: %{site_id: s.id, entry_type: "site", role: tm.role}
        )
      else
        my_team_query =
          from(tm in Teams.Membership,
            inner_join: t in assoc(tm, :team),
            inner_join: s in assoc(t, :sites),
            where: tm.user_id == ^user.id and tm.role != :guest,
            where: tm.is_autocreated == true,
            where: not t.setup_complete,
            select: %{site_id: s.id, entry_type: "site", role: tm.role}
          )

        guest_membership_query =
          from(tm in Teams.Membership,
            inner_join: gm in assoc(tm, :guest_memberships),
            inner_join: s in assoc(gm, :site),
            where: tm.user_id == ^user.id and tm.role == :guest,
            select: %{
              site_id: s.id,
              entry_type: "site",
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

        from(s in my_team_query,
          union_all: ^guest_membership_query
        )
      end

    from(u in subquery(all_query),
      inner_join: s in ^Plausible.Site.regular(),
      on: u.site_id == s.id,
      as: :site,
      left_join: up in Site.UserPreference,
      on: up.site_id == s.id and up.user_id == ^user.id,
      select: %{
        s
        | entry_type:
            selected_as(
              fragment(
                """
                CASE
                  WHEN ? IS NOT NULL THEN 'pinned_site'
                  ELSE ?
                END
                """,
                up.pinned_at,
                u.entry_type
              ),
              :entry_type
            ),
          pinned_at: selected_as(up.pinned_at, :pinned_at),
          memberships: [
            %{
              role: type(u.role, ^@role_type),
              site_id: s.id,
              site: s
            }
          ]
      },
      order_by: [
        asc: selected_as(:entry_type),
        desc: selected_as(:pinned_at),
        asc: s.domain
      ]
    )
    |> maybe_filter_by_domain(domain_filter)
    |> Repo.paginate(pagination_params)
  end

  defp maybe_filter_by_domain(query, domain)
       when byte_size(domain) >= 1 and byte_size(domain) <= 64 do
    where(query, [site: s], ilike(s.domain, ^"%#{domain}%"))
  end

  defp maybe_filter_by_domain(query, _), do: query
end
