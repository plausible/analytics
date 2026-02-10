defmodule Plausible.Teams.Sites do
  @moduledoc false
  @sample_threshold 10_000_000

  import Ecto.Query
  use Plausible.Stats.SQL.Fragments

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Teams

  def list_with_clickhouse(user, team, opts \\ []) do
    # TODO maybe filter by domain
    date_range = Keyword.get(opts, :date_range, {:last_n_days, 30})
    now = Keyword.get(opts, :now, DateTime.utc_now())

    {relative_start_date, relative_end_date} = calculate_relative_dates(date_range, now)

    all_query =
      if Teams.setup?(team) do
        from(tm in Teams.Membership,
          inner_join: t in assoc(tm, :team),
          inner_join: s in assoc(t, :sites),
          where: tm.user_id == ^user.id and tm.role != :guest,
          where: tm.team_id == ^team.id,
          where: not s.consolidated,
          select: struct(s, [:id, :domain, :timezone])
        )
      else
        my_team_query =
          from(tm in Teams.Membership,
            inner_join: t in assoc(tm, :team),
            inner_join: s in assoc(t, :sites),
            where: not s.consolidated,
            where: tm.user_id == ^user.id and tm.role != :guest,
            where: tm.is_autocreated,
            where: not t.setup_complete,
            select: struct(s, [:id, :domain, :timezone])
          )

        guest_membership_query =
          from(tm in Teams.Membership,
            inner_join: gm in assoc(tm, :guest_memberships),
            inner_join: s in assoc(gm, :site),
            where: not s.consolidated,
            where: tm.user_id == ^user.id and tm.role == :guest,
            select: struct(s, [:id, :domain, :timezone])
          )

        from(s in my_team_query,
          union_all: ^guest_membership_query
        )
      end

    all_query =
      from(u in subquery(all_query),
        inner_join: s in ^Plausible.Site.regular(),
        on: u.id == s.id,
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
                  "site"
                ),
                :entry_type
              ),
            pinned_at: selected_as(up.pinned_at, :pinned_at)
        }
      )

    clickhouse_query =
      from(e in Plausible.ClickhouseEventV2,
        hints: unsafe_fragment(^"SAMPLE #{@sample_threshold}"),
        right_join: sites in subquery(all_query, prefix: "postgres_remote"),
        on: fragment("CAST(?, 'UInt64')", sites.id) == e.site_id,
        select: %{
          entry_type: selected_as(sites.entry_type, :entry_type),
          pinned_at: selected_as(sites.pinned_at, :pinned_at),
          site_id: sites.id,
          domain: sites.domain,
          timezone: sites.timezone,
          visitors:
            selected_as(
              scale_sample(fragment("uniqIf(?, ? != 0)", e.user_id, e.site_id)),
              :visitors
            )
        },
        where:
          e.site_id == 0 or
            fragment(
              """
              ? >= toDateTime(concat(?, ' 00:00:00'), ?)
              AND ? <= toDateTime(concat(?, ' 23:59:59'), ?)
              """,
              e.timestamp,
              ^relative_start_date,
              sites.timezone,
              e.timestamp,
              ^relative_end_date,
              sites.timezone
            ),
        group_by: [sites.id, sites.domain, sites.entry_type, sites.pinned_at, sites.timezone],
        order_by: [
          asc: selected_as(:entry_type),
          desc: selected_as(:pinned_at),
          desc: selected_as(:visitors)
        ]
      )

    clickhouse_query |> dbg()

    Paginator.paginate(
      clickhouse_query,
      [limit: 24, cursor_fields: [:visitors, :id], sort_direction: :desc],
      Plausible.ClickhouseRepo,
      []
    )
  end

  # Helper function to calculate date range for ClickHouse queries
  # Returns {start_date, end_date} as Date structs or date strings
  defp calculate_relative_dates({:last_n_days, n}, now) do
    end_date = now |> DateTime.to_date() |> Date.add(-1)
    start_date = end_date |> Date.add(-(n - 1))
    {Date.to_string(start_date), Date.to_string(end_date)}
  end

  defp calculate_relative_dates(:day, now) do
    date = DateTime.to_date(now)
    {Date.to_string(date), Date.to_string(date)}
  end

  defp calculate_relative_dates(:month, now) do
    date = DateTime.to_date(now)
    start_date = Date.beginning_of_month(date)
    end_date = Date.end_of_month(date)
    {Date.to_string(start_date), Date.to_string(end_date)}
  end

  defp calculate_relative_dates(:year, now) do
    date = DateTime.to_date(now)
    start_date = %{date | month: 1, day: 1}
    end_date = %{date | month: 12, day: 31}
    {Date.to_string(start_date), Date.to_string(end_date)}
  end

  defp calculate_relative_dates({:date_range, from, to}, _now) do
    {Date.to_string(from), Date.to_string(to)}
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
