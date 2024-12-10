defmodule Plausible.Teams.Billing do
  @moduledoc false

  use Plausible

  import Ecto.Query

  alias Plausible.Billing.EnterprisePlan
  alias Plausible.Billing.Plans
  alias Plausible.Billing.Subscription
  alias Plausible.Billing.Subscriptions
  alias Plausible.Repo
  alias Plausible.Teams

  alias Plausible.Billing.{Plan, Plans, EnterprisePlan, Feature}
  alias Plausible.Billing.Feature.{Goals, Props, StatsAPI}

  require Plausible.Billing.Subscription.Status

  @team_member_limit_for_trials 3
  @limit_sites_since ~D[2021-05-05]
  @site_limit_for_trials 10

  @type cycles_usage() :: %{cycle() => usage_cycle()}

  @typep cycle :: :current_cycle | :last_cycle | :penultimate_cycle

  @typep usage_cycle :: %{
           date_range: Date.Range.t(),
           pageviews: non_neg_integer(),
           custom_events: non_neg_integer(),
           total: non_neg_integer()
         }

  @typep last_30_days_usage() :: %{:last_30_days => usage_cycle()}
  @typep monthly_pageview_usage() :: cycles_usage() | last_30_days_usage()

  def get_subscription(nil), do: nil

  def get_subscription(%Teams.Team{subscription: %Subscription{} = subscription}),
    do: subscription

  def get_subscription(%Teams.Team{} = team) do
    Teams.with_subscription(team).subscription
  end

  def change_plan(team, new_plan_id) do
    subscription = active_subscription_for(team)
    plan = Plausible.Billing.Plans.find(new_plan_id)

    limit_checking_opts =
      if team.allow_next_upgrade_override do
        [ignore_pageview_limit: true]
      else
        []
      end

    usage = quota_usage(team)

    with :ok <-
           Plausible.Billing.Quota.ensure_within_plan_limits(usage, plan, limit_checking_opts),
         do: do_change_plan(subscription, new_plan_id)
  end

  defp do_change_plan(subscription, new_plan_id) do
    res =
      Plausible.Billing.paddle_api().update_subscription(subscription.paddle_subscription_id, %{
        plan_id: new_plan_id
      })

    case res do
      {:ok, response} ->
        amount = :erlang.float_to_binary(response["next_payment"]["amount"] / 1, decimals: 2)

        Subscription.changeset(subscription, %{
          paddle_plan_id: Integer.to_string(response["plan_id"]),
          next_bill_amount: amount,
          next_bill_date: response["next_payment"]["date"]
        })
        |> Repo.update()

      e ->
        e
    end
  end

  def enterprise_configured?(nil), do: false

  def enterprise_configured?(%Teams.Team{} = team) do
    team
    |> Ecto.assoc(:enterprise_plan)
    |> Repo.exists?()
  end

  def latest_enterprise_plan_with_price(team, customer_ip) do
    enterprise_plan =
      Repo.one!(
        from(e in EnterprisePlan,
          where: e.team_id == ^team.id,
          order_by: [desc: e.inserted_at],
          limit: 1
        )
      )

    {enterprise_plan, Plausible.Billing.Plans.get_price_for(enterprise_plan, customer_ip)}
  end

  def has_active_subscription?(nil), do: false

  def has_active_subscription?(team) do
    team
    |> active_subscription_query()
    |> Repo.exists?()
  end

  def active_subscription_for(nil), do: nil

  def active_subscription_for(team) do
    team
    |> active_subscription_query()
    |> Repo.one()
  end

  @spec check_needs_to_upgrade(Teams.Team.t() | nil) ::
          {:needs_to_upgrade, :no_trial | :no_active_subscription | :grace_period_ended}
          | :no_upgrade_needed
  def check_needs_to_upgrade(nil), do: {:needs_to_upgrade, :no_trial}

  def check_needs_to_upgrade(team) do
    team = Teams.with_subscription(team)

    trial_over? =
      not is_nil(team.trial_expiry_date) and
        Date.before?(team.trial_expiry_date, Date.utc_today())

    subscription_active? = Subscriptions.active?(team.subscription)

    cond do
      is_nil(team.trial_expiry_date) and not subscription_active? ->
        {:needs_to_upgrade, :no_trial}

      trial_over? and not subscription_active? ->
        {:needs_to_upgrade, :no_active_subscription}

      Plausible.Auth.GracePeriod.expired?(team) ->
        {:needs_to_upgrade, :grace_period_ended}

      true ->
        :no_upgrade_needed
    end
  end

  @doc """
  Enterprise plans are always allowed to add more sites (even when
  over limit) to avoid service disruption. Their usage is checked
  in a background job instead (see `check_usage.ex`).
  """
  def ensure_can_add_new_site(nil) do
    :ok
  end

  def ensure_can_add_new_site(team) do
    team = Teams.with_subscription(team)

    case Plans.get_subscription_plan(team.subscription) do
      %EnterprisePlan{} ->
        :ok

      _ ->
        usage = site_usage(team)
        limit = site_limit(team)

        if Plausible.Billing.Quota.below_limit?(usage, limit) do
          :ok
        else
          {:error, {:over_limit, limit}}
        end
    end
  end

  def site_limit(nil) do
    @site_limit_for_trials
  end

  def site_limit(team) do
    {:ok, user} = Teams.get_owner(team)

    if Timex.before?(user.inserted_at, @limit_sites_since) do
      :unlimited
    else
      get_site_limit_from_plan(team)
    end
  end

  @doc """
  Returns the number of sites the given team owns.
  """
  @spec site_usage(Teams.Team.t()) :: non_neg_integer()
  def site_usage(nil), do: 0

  def site_usage(team) do
    team
    |> Teams.owned_sites()
    |> length()
  end

  defp get_site_limit_from_plan(nil) do
    @site_limit_for_trials
  end

  defp get_site_limit_from_plan(team) do
    team =
      Teams.with_subscription(team)

    case Plans.get_subscription_plan(team.subscription) do
      %{site_limit: site_limit} -> site_limit
      :free_10k -> 50
      nil -> @site_limit_for_trials
    end
  end

  def team_member_limit(nil) do
    @team_member_limit_for_trials
  end

  def team_member_limit(team) do
    team = Teams.with_subscription(team)

    case Plans.get_subscription_plan(team.subscription) do
      %{team_member_limit: limit} -> limit
      :free_10k -> :unlimited
      nil -> @team_member_limit_for_trials
    end
  end

  @doc """
  Returns a full usage report for the team.

  ### Options

  * `pending_ownership_site_ids` - a list of site IDs from which to count
  additional usage. This allows us to look at the total usage from pending
  ownerships and owned sites at the same time, which is useful, for example,
  when deciding whether to let the team owner upgrade to a plan, or accept a 
  site ownership.

  * `with_features` - when `true`, the returned map will contain features
  usage. Also counts usage from `pending_ownership_site_ids` if that option
  is given.
  """
  def quota_usage(team, opts \\ []) do
    team = Teams.with_subscription(team)
    with_features? = Keyword.get(opts, :with_features, false)
    pending_site_ids = Keyword.get(opts, :pending_ownership_site_ids, [])
    team_site_ids = Teams.owned_sites_ids(team)
    all_site_ids = pending_site_ids ++ team_site_ids

    monthly_pageviews = monthly_pageview_usage(team, all_site_ids)
    team_member_usage = team_member_usage(team, pending_ownership_site_ids: pending_site_ids)

    basic_usage = %{
      monthly_pageviews: monthly_pageviews,
      team_members: team_member_usage,
      sites: length(all_site_ids)
    }

    if with_features? do
      Map.put(basic_usage, :features, features_usage(team, all_site_ids))
    else
      basic_usage
    end
  end

  @monthly_pageview_limit_for_free_10k 10_000
  @monthly_pageview_limit_for_trials :unlimited

  def monthly_pageview_limit(nil) do
    @monthly_pageview_limit_for_trials
  end

  def monthly_pageview_limit(%Teams.Team{} = team) do
    team = Teams.with_subscription(team)
    monthly_pageview_limit(team.subscription)
  end

  def monthly_pageview_limit(subscription) do
    case Plans.get_subscription_plan(subscription) do
      %EnterprisePlan{monthly_pageview_limit: limit} ->
        limit

      %Plan{monthly_pageview_limit: limit} ->
        limit

      :free_10k ->
        @monthly_pageview_limit_for_free_10k

      _any ->
        if subscription do
          Sentry.capture_message("Unknown monthly pageview limit for plan",
            extra: %{paddle_plan_id: subscription.paddle_plan_id}
          )
        end

        @monthly_pageview_limit_for_trials
    end
  end

  @doc """
  Queries the ClickHouse database for the monthly pageview usage. If the given team's
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

  Given only a team as input, the usage is queried from across all the sites that the
  team owns. Alternatively, given an optional argument of `site_ids`, the usage from
  across all those sites is queried instead.
  """
  @spec monthly_pageview_usage(Teams.Team.t(), list() | nil) :: monthly_pageview_usage()
  def monthly_pageview_usage(team, site_ids \\ nil)

  def monthly_pageview_usage(team, nil) do
    monthly_pageview_usage(team, Teams.owned_sites_ids(team))
  end

  def monthly_pageview_usage(nil, _site_ids) do
    %{last_30_days: usage_cycle(nil, :last_30_days, [])}
  end

  def monthly_pageview_usage(team, site_ids) do
    team = Teams.with_subscription(team)
    active_subscription? = Subscriptions.active?(team.subscription)

    if active_subscription? and team.subscription.last_bill_date != nil do
      [:current_cycle, :last_cycle, :penultimate_cycle]
      |> Task.async_stream(fn cycle ->
        {cycle, usage_cycle(team, cycle, site_ids)}
      end)
      |> Enum.into(%{}, fn {:ok, cycle_usage} -> cycle_usage end)
    else
      %{last_30_days: usage_cycle(team, :last_30_days, site_ids)}
    end
  end

  @spec team_member_usage(Teams.Team.t(), Keyword.t()) :: non_neg_integer()
  @doc """
  Returns the total count of team members associated with the team's sites.

  * The given team's owner is not counted as a team member.

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
  def team_member_usage(team, opts \\ [])
  def team_member_usage(nil, _), do: 0

  def team_member_usage(team, opts) do
    {:ok, owner} = Teams.get_owner(team)
    exclude_emails = Keyword.get(opts, :exclude_emails, []) ++ [owner.email]

    pending_site_ids = Keyword.get(opts, :pending_ownership_site_ids, [])

    team
    |> query_team_member_emails(pending_site_ids, exclude_emails)
    |> Repo.aggregate(:count)
  end

  def usage_cycle(team, cycle, owned_site_ids \\ nil, today \\ Date.utc_today())

  def usage_cycle(team, cycle, nil, today) do
    owned_site_ids = team |> Teams.owned_sites() |> Enum.map(& &1.id)
    usage_cycle(team, cycle, owned_site_ids, today)
  end

  def usage_cycle(_team, :last_30_days, owned_site_ids, today) do
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

  def usage_cycle(team, cycle, owned_site_ids, today) do
    team = Teams.with_subscription(team)
    last_bill_date = team.subscription.last_bill_date

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

  @spec features_usage(Teams.Team.t() | nil, list() | nil) :: [atom()]
  @doc """
  Given only a team, this function returns the features used across all the
  sites this team owns + StatsAPI if any team user has a configured Stats API key.

  Given a team, and a list of site_ids, returns the features used by those
  sites instead + StatsAPI if any user in the team has a configured Stats API key.

  The team can also be passed as `nil`, in which case we will never return
  Stats API as a used feature.
  """
  def features_usage(team, site_ids \\ nil)

  def features_usage(nil, nil), do: []

  def features_usage(%Teams.Team{} = team, nil) do
    owned_site_ids = team |> Teams.owned_sites() |> Enum.map(& &1.id)
    features_usage(team, owned_site_ids)
  end

  def features_usage(%Teams.Team{} = team, owned_site_ids) when is_list(owned_site_ids) do
    site_scoped_feature_usage = features_usage(nil, owned_site_ids)

    stats_api_used? =
      Repo.exists?(
        from tm in Plausible.Teams.Membership,
          as: :team_membership,
          where: tm.team_id == ^team.id,
          where:
            exists(
              from ak in Plausible.Auth.ApiKey,
                where: ak.user_id == parent_as(:team_membership).user_id
            )
      )

    if stats_api_used? do
      site_scoped_feature_usage ++ [Feature.StatsAPI]
    else
      site_scoped_feature_usage
    end
  end

  def features_usage(nil, site_ids) when is_list(site_ids) do
    props_usage_q =
      from s in Plausible.Site,
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
      if Repo.exists?(query), do: acc ++ [feature], else: acc
    end)
  end

  defp query_team_member_emails(team, pending_ownership_site_ids, exclude_emails) do
    pending_owner_memberships_q =
      from s in Plausible.Site,
        inner_join: t in assoc(s, :team),
        inner_join: tm in assoc(t, :team_memberships),
        inner_join: u in assoc(tm, :user),
        where: s.id in ^pending_ownership_site_ids,
        where: tm.role == :owner,
        where: u.email not in ^exclude_emails,
        select: %{email: u.email}

    pending_memberships_q =
      from tm in Teams.Membership,
        inner_join: u in assoc(tm, :user),
        left_join: gm in assoc(tm, :guest_memberships),
        where: gm.site_id in ^pending_ownership_site_ids,
        where: u.email not in ^exclude_emails,
        select: %{email: u.email}

    pending_invitations_q =
      from ti in Teams.Invitation,
        inner_join: gi in assoc(ti, :guest_invitations),
        where: gi.site_id in ^pending_ownership_site_ids,
        where: ti.email not in ^exclude_emails,
        select: %{email: ti.email}

    team_memberships_q =
      from tm in Teams.Membership,
        inner_join: u in assoc(tm, :user),
        where: tm.team_id == ^team.id,
        where: u.email not in ^exclude_emails,
        select: %{email: u.email}

    team_invitations_q =
      from ti in Teams.Invitation,
        where: ti.team_id == ^team.id,
        where: ti.email not in ^exclude_emails,
        select: %{email: ti.email}

    pending_memberships_q
    |> union(^pending_owner_memberships_q)
    |> union(^pending_invitations_q)
    |> union(^team_memberships_q)
    |> union(^team_invitations_q)
  end

  def allowed_features_for(nil) do
    [Goals]
  end

  def allowed_features_for(team) do
    team = Teams.with_subscription(team)

    case Plans.get_subscription_plan(team.subscription) do
      %EnterprisePlan{features: features} ->
        features

      %Plan{features: features} ->
        features

      :free_10k ->
        [Goals, Props, StatsAPI]

      nil ->
        if Teams.on_trial?(team) do
          Feature.list()
        else
          [Goals]
        end
    end
  end

  defp active_subscription_query(team) do
    from(s in Plausible.Billing.Subscription,
      where:
        s.team_id == ^team.id and s.status == ^Plausible.Billing.Subscription.Status.active(),
      order_by: [desc: s.inserted_at],
      limit: 1
    )
  end
end
