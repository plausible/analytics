defmodule Plausible.Billing.Quota.Usage do
  use Plausible
  import Ecto.Query
  alias Plausible.Users
  alias Plausible.Auth.User
  alias Plausible.Site
  alias Plausible.Billing.{Subscriptions}
  alias Plausible.Billing.Feature.{RevenueGoals, Funnels, Props, StatsAPI}

  @type cycles_usage() :: %{cycle() => usage_cycle()}

  @typep cycle :: :current_cycle | :last_cycle | :penultimate_cycle
  @typep last_30_days_usage() :: %{:last_30_days => usage_cycle()}
  @typep monthly_pageview_usage() :: cycles_usage() | last_30_days_usage()

  @typep usage_cycle :: %{
           date_range: Date.Range.t(),
           pageviews: non_neg_integer(),
           custom_events: non_neg_integer(),
           total: non_neg_integer()
         }

  def usage(user, opts \\ []) do
    basic_usage = %{
      monthly_pageviews: monthly_pageview_usage(user),
      team_members: team_member_usage(user),
      sites: site_usage(user)
    }

    if Keyword.get(opts, :with_features) == true do
      basic_usage
      |> Map.put(:features, features_usage(user))
    else
      basic_usage
    end
  end

  @spec site_usage(User.t()) :: non_neg_integer()
  @doc """
  Returns the number of sites the given user owns.
  """
  def site_usage(user) do
    Plausible.Sites.owned_sites_count(user)
  end

  @doc """
  Queries the ClickHouse database for the monthly pageview usage. If the given user's
  subscription is `active`, `past_due`, or a `deleted` (but not yet expired), a map
  with the following structure is returned:

  ```elixir
  %{
    current_cycle: usage_cycle(),
    last_cycle: usage_cycle(),
    penultimate_cycle: usage_cycle()
  }
  ```

  In all other cases of the subscription status (or a `free_10k` subscription which
  does not have a `last_bill_date` defined) - the following structure is returned:

  ```elixir
  %{last_30_days: usage_cycle()}
  ```

  Given only a user as input, the usage is queried from across all the sites that the
  user owns. Alternatively, given an optional argument of `site_ids`, the usage from
  across all those sites is queried instead.
  """
  @spec monthly_pageview_usage(User.t(), list() | nil) :: monthly_pageview_usage()
  def monthly_pageview_usage(user, site_ids \\ nil)

  def monthly_pageview_usage(user, nil) do
    monthly_pageview_usage(user, Plausible.Sites.owned_site_ids(user))
  end

  def monthly_pageview_usage(user, site_ids) do
    active_subscription? = Subscriptions.active?(user.subscription)

    if active_subscription? && user.subscription.last_bill_date do
      [:current_cycle, :last_cycle, :penultimate_cycle]
      |> Task.async_stream(fn cycle ->
        %{cycle => usage_cycle(user, cycle, site_ids)}
      end)
      |> Enum.map(fn {:ok, cycle_usage} -> cycle_usage end)
      |> Enum.reduce(%{}, &Map.merge/2)
    else
      %{last_30_days: usage_cycle(user, :last_30_days, site_ids)}
    end
  end

  @spec usage_cycle(User.t(), :last_30_days | cycle(), list() | nil, Date.t()) :: usage_cycle()
  def usage_cycle(user, cycle, owned_site_ids \\ nil, today \\ Timex.today())

  def usage_cycle(user, cycle, nil, today) do
    usage_cycle(user, cycle, Plausible.Sites.owned_site_ids(user), today)
  end

  def usage_cycle(_user, :last_30_days, owned_site_ids, today) do
    date_range = Date.range(Timex.shift(today, days: -30), today)

    {pageviews, custom_events} =
      Plausible.Stats.Clickhouse.usage_breakdown(owned_site_ids, date_range)

    %{
      date_range: date_range,
      pageviews: pageviews,
      custom_events: custom_events,
      total: pageviews + custom_events
    }
  end

  def usage_cycle(user, cycle, owned_site_ids, today) do
    user = Users.with_subscription(user)
    last_bill_date = user.subscription.last_bill_date

    normalized_last_bill_date =
      Timex.shift(last_bill_date, months: Timex.diff(today, last_bill_date, :months))

    date_range =
      case cycle do
        :current_cycle ->
          Date.range(
            normalized_last_bill_date,
            Timex.shift(normalized_last_bill_date, months: 1, days: -1)
          )

        :last_cycle ->
          Date.range(
            Timex.shift(normalized_last_bill_date, months: -1),
            Timex.shift(normalized_last_bill_date, days: -1)
          )

        :penultimate_cycle ->
          Date.range(
            Timex.shift(normalized_last_bill_date, months: -2),
            Timex.shift(normalized_last_bill_date, days: -1, months: -1)
          )
      end

    {pageviews, custom_events} =
      Plausible.Stats.Clickhouse.usage_breakdown(owned_site_ids, date_range)

    %{
      date_range: date_range,
      pageviews: pageviews,
      custom_events: custom_events,
      total: pageviews + custom_events
    }
  end

  @spec team_member_usage(User.t()) :: integer()
  @doc """
  Returns the total count of team members associated with the user's sites.

  * The given user (i.e. the owner) is not counted as a team member.

  * Pending invitations are counted as team members even before accepted.

  * Users are counted uniquely - i.e. even if an account is associated with
    many sites owned by the given user, they still count as one team member.

  * Specific e-mails can be excluded from the count, so that where necessary,
    we can ensure inviting the same person(s) to more than 1 sites is allowed
  """
  def team_member_usage(user, opts \\ []) do
    {:ok, opts} = Keyword.validate(opts, site: nil, exclude_emails: [])

    user
    |> team_member_usage_query(opts)
    |> Plausible.Repo.aggregate(:count)
  end

  defp team_member_usage_query(user, opts) do
    owned_sites_query = owned_sites_query(user)

    excluded_emails =
      opts
      |> Keyword.get(:exclude_emails, [])
      |> List.wrap()

    site = opts[:site]

    owned_sites_query =
      if site do
        where(owned_sites_query, [os], os.site_id == ^site.id)
      else
        owned_sites_query
      end

    team_members_query =
      from os in subquery(owned_sites_query),
        inner_join: sm in Site.Membership,
        on: sm.site_id == os.site_id,
        inner_join: u in assoc(sm, :user),
        where: sm.role != :owner,
        select: u.email

    team_members_query =
      if excluded_emails != [] do
        team_members_query |> where([..., u], u.email not in ^excluded_emails)
      else
        team_members_query
      end

    query =
      from i in Plausible.Auth.Invitation,
        inner_join: os in subquery(owned_sites_query),
        on: i.site_id == os.site_id,
        where: i.role != :owner,
        select: i.email,
        union: ^team_members_query

    if excluded_emails != [] do
      query
      |> where([i], i.email not in ^excluded_emails)
    else
      query
    end
  end

  @spec features_usage(User.t() | Site.t()) :: [atom()]
  @doc """
  Given a user, this function returns the features used across all the sites
  this user owns + StatsAPI if the user has a configured Stats API key.

  Given a site, returns the features used by the site.
  """
  def features_usage(%User{} = user) do
    props_usage_query =
      from s in Site,
        inner_join: os in subquery(owned_sites_query(user)),
        on: s.id == os.site_id,
        where: fragment("cardinality(?) > 0", s.allowed_event_props)

    revenue_goals_usage =
      from g in Plausible.Goal,
        inner_join: os in subquery(owned_sites_query(user)),
        on: g.site_id == os.site_id,
        where: not is_nil(g.currency)

    stats_api_usage = from a in Plausible.Auth.ApiKey, where: a.user_id == ^user.id

    queries =
      on_ee do
        funnels_usage_query =
          from f in "funnels",
            inner_join: os in subquery(owned_sites_query(user)),
            on: f.site_id == os.site_id

        [
          {Props, props_usage_query},
          {Funnels, funnels_usage_query},
          {RevenueGoals, revenue_goals_usage},
          {StatsAPI, stats_api_usage}
        ]
      else
        [
          {Props, props_usage_query},
          {RevenueGoals, revenue_goals_usage},
          {StatsAPI, stats_api_usage}
        ]
      end

    Enum.reduce(queries, [], fn {feature, query}, acc ->
      if Plausible.Repo.exists?(query), do: acc ++ [feature], else: acc
    end)
  end

  def features_usage(%Site{} = site) do
    props_exist = is_list(site.allowed_event_props) && site.allowed_event_props != []

    funnels_exist =
      on_ee do
        Plausible.Repo.exists?(from f in Plausible.Funnel, where: f.site_id == ^site.id)
      else
        false
      end

    revenue_goals_exist =
      Plausible.Repo.exists?(
        from g in Plausible.Goal, where: g.site_id == ^site.id and not is_nil(g.currency)
      )

    used_features = [
      {Props, props_exist},
      {Funnels, funnels_exist},
      {RevenueGoals, revenue_goals_exist}
    ]

    for {f_mod, used?} <- used_features, used?, f_mod.enabled?(site), do: f_mod
  end

  defp owned_sites_query(user) do
    from sm in Site.Membership,
      where: sm.role == :owner and sm.user_id == ^user.id,
      select: %{site_id: sm.site_id}
  end
end
