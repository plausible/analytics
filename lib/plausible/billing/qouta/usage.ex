defmodule Plausible.Billing.Quota.Usage do
  @moduledoc false

  use Plausible
  import Ecto.Query
  alias Plausible.Users
  alias Plausible.Auth.User
  alias Plausible.Site
  alias Plausible.Billing.{Subscriptions, Feature}

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

  @doc """
  Returns a full usage report for the user.

  ### Options

  * `pending_ownership_site_ids` - a list of site IDs from which to count
    additional usage. This allows us to look at the total usage from pending
    ownerships and owned sites at the same time, which is useful, for example,
    when deciding whether to let the user upgrade to a plan, or accept a site
    ownership.

  * `with_features` - when `true`, the returned map will contain features
    usage. Also counts usage from `pending_ownership_site_ids` if that option
    is given.
  """
  def usage(user, opts \\ []) do
    owned_site_ids = Plausible.Sites.owned_site_ids(user)
    pending_ownership_site_ids = Keyword.get(opts, :pending_ownership_site_ids, [])
    all_site_ids = Enum.uniq(owned_site_ids ++ pending_ownership_site_ids)

    basic_usage = %{
      monthly_pageviews: monthly_pageview_usage(user, all_site_ids),
      team_members:
        team_member_usage(user, pending_ownership_site_ids: pending_ownership_site_ids),
      sites: length(all_site_ids)
    }

    if Keyword.get(opts, :with_features) == true do
      basic_usage
      |> Map.put(:features, features_usage(user, all_site_ids))
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
  def usage_cycle(user, cycle, owned_site_ids \\ nil, today \\ Date.utc_today())

  def usage_cycle(user, cycle, nil, today) do
    usage_cycle(user, cycle, Plausible.Sites.owned_site_ids(user), today)
  end

  def usage_cycle(_user, :last_30_days, owned_site_ids, today) do
    date_range = Date.range(Date.shift(today, day: -30), today)

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
      Date.shift(last_bill_date, month: Timex.diff(today, last_bill_date, :months))

    date_range =
      case cycle do
        :current_cycle ->
          Date.range(
            normalized_last_bill_date,
            Date.shift(normalized_last_bill_date, month: 1, day: -1)
          )

        :last_cycle ->
          Date.range(
            Date.shift(normalized_last_bill_date, month: -1),
            Date.shift(normalized_last_bill_date, day: -1)
          )

        :penultimate_cycle ->
          Date.range(
            Date.shift(normalized_last_bill_date, month: -2),
            Date.shift(normalized_last_bill_date, day: -1, month: -1)
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

  @spec team_member_usage(User.t(), Keyword.t()) :: non_neg_integer()
  @doc """
  Returns the total count of team members associated with the user's sites.

  * The given user (i.e. the owner) is not counted as a team member.

  * Pending invitations (but not ownership transfers) are counted as team
    members even before accepted.

  * Users are counted uniquely - i.e. even if an account is associated with
    many sites owned by the given user, they still count as one team member.

  ### Options

  * `exclude_emails` - a list of emails to not count towards the usage. This
    allows us to exclude a user from being counted as a team member when
    checking whether a site invitation can be created for that same user.

  * `pending_ownership_site_ids` - a list of site IDs from which to count
    additional team member usage. Without this option, usage is queried only
    across sites owned by the given user.
  """
  def team_member_usage(user, opts \\ [])

  def team_member_usage(%User{} = user, opts) do
    exclude_emails = Keyword.get(opts, :exclude_emails, []) ++ [user.email]

    q =
      user
      |> Plausible.Sites.owned_site_ids()
      |> query_team_member_emails()

    q =
      case Keyword.get(opts, :pending_ownership_site_ids) do
        [_ | _] = site_ids -> union(q, ^query_team_member_emails(site_ids))
        _ -> q
      end

    from(u in subquery(q),
      where: u.email not in ^exclude_emails,
      distinct: u.email
    )
    |> Plausible.Repo.aggregate(:count)
  end

  def query_team_member_emails(site_ids) do
    memberships_q =
      from sm in Site.Membership,
        where: sm.site_id in ^site_ids,
        inner_join: u in assoc(sm, :user),
        select: %{email: u.email}

    invitations_q =
      from i in Plausible.Auth.Invitation,
        where: i.site_id in ^site_ids and i.role != :owner,
        select: %{email: i.email}

    union(memberships_q, ^invitations_q)
  end

  @spec features_usage(User.t() | nil, list() | nil) :: [atom()]
  @doc """
  Given only a user, this function returns the features used across all the
  sites this user owns + StatsAPI if the user has a configured Stats API key.

  Given a user, and a list of site_ids, returns the features used by those
  sites instead + StatsAPI if the user has a configured Stats API key.

  The user can also be passed as `nil`, in which case we will never return
  Stats API as a used feature.
  """
  def features_usage(user, site_ids \\ nil)

  def features_usage(%User{} = user, nil) do
    site_ids = Plausible.Sites.owned_site_ids(user)
    features_usage(user, site_ids)
  end

  def features_usage(%User{} = user, site_ids) when is_list(site_ids) do
    site_scoped_feature_usage = features_usage(nil, site_ids)

    stats_api_used? =
      from(a in Plausible.Auth.ApiKey, where: a.user_id == ^user.id)
      |> Plausible.Repo.exists?()

    if stats_api_used? do
      site_scoped_feature_usage ++ [Feature.StatsAPI]
    else
      site_scoped_feature_usage
    end
  end

  def features_usage(nil, site_ids) when is_list(site_ids) do
    props_usage_q =
      from s in Site,
        where: s.id in ^site_ids and fragment("cardinality(?) > 0", s.allowed_event_props)

    revenue_goals_usage_q =
      from g in Plausible.Goal,
        where: g.site_id in ^site_ids and not is_nil(g.currency)

    queries =
      on_ee do
        funnels_usage_q = from f in "funnels", where: f.site_id in ^site_ids

        [
          {Feature.Props, props_usage_q},
          {Feature.Funnels, funnels_usage_q},
          {Feature.RevenueGoals, revenue_goals_usage_q}
        ]
      else
        [
          {Feature.Props, props_usage_q},
          {Feature.RevenueGoals, revenue_goals_usage_q}
        ]
      end

    Enum.reduce(queries, [], fn {feature, query}, acc ->
      if Plausible.Repo.exists?(query), do: acc ++ [feature], else: acc
    end)
  end
end
