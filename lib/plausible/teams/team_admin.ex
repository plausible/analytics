defmodule Plausible.Teams.TeamAdmin do
  @moduledoc """
  Kaffy CRM definition for Team.
  """

  use Plausible
  use Plausible.Repo

  alias Plausible.Billing.Subscription
  alias Plausible.Teams

  require Plausible.Billing.Subscription.Status

  def custom_index_query(conn, _schema, query) do
    search =
      (conn.params["custom_search"] || "")
      |> String.trim()
      |> String.replace("%", "\%")
      |> String.replace("_", "\_")

    search_term = "%#{search}%"

    member_query =
      from t in Plausible.Teams.Team,
        left_join: tm in assoc(t, :team_memberships),
        left_join: u in assoc(tm, :user),
        where: t.id == parent_as(:team).id,
        where: ilike(u.email, ^search_term) or ilike(u.name, ^search_term),
        select: 1

    from(t in query,
      as: :team,
      left_lateral_join: s in subquery(Teams.last_subscription_join_query()),
      on: true,
      preload: [:owners, team_memberships: :user, subscription: s],
      or_where: ilike(t.name, ^search_term),
      or_where: exists(member_query)
    )
  end

  def index(_) do
    [
      name: %{value: &team_name/1},
      inserted_at: %{name: "Created at", value: &format_date(&1.inserted_at)},
      other_members: %{value: &get_other_members/1},
      trial_expiry_date: %{name: "Trial expiry", value: &format_date(&1.trial_expiry_date)},
      subscription_plan: %{value: &subscription_plan/1},
      subscription_status: %{value: &subscription_status/1},
      grace_period: %{value: &grace_period_status/1},
      accept_traffic_until: %{
        name: "Accept traffic until",
        value: &format_date(&1.accept_traffic_until)
      }
    ]
  end

  def form_fields(_) do
    [
      name: nil,
      trial_expiry_date: %{
        help_text: "Change will also update Accept Traffic Until date"
      },
      allow_next_upgrade_override: nil,
      accept_traffic_until: %{
        help_text: "Change will take up to 15 minutes to propagate"
      }
    ]
  end

  def resource_actions(_) do
    [
      unlock: %{
        name: "Unlock",
        action: fn _, team -> unlock(team) end
      },
      lock: %{
        name: "Lock",
        action: fn _, team -> lock(team) end
      }
    ]
  end

  def delete(_conn, %{data: _team}) do
    # TODO: Implement custom team removal
    "Cannot remove the team for now"
  end

  defp lock(team) do
    if team.grace_period do
      Plausible.Billing.SiteLocker.set_lock_status_for(team, true)
      Plausible.Teams.end_grace_period(team)
      {:ok, team}
    else
      {:error, team, "No active grace period on this team"}
    end
  end

  defp unlock(team) do
    if team.grace_period do
      Plausible.Teams.remove_grace_period(team)
      Plausible.Billing.SiteLocker.set_lock_status_for(team, false)
      {:ok, team}
    else
      {:error, team, "No active grace period on this team"}
    end
  end

  defp team_name(team) do
    owners = Enum.map_join(team.owners, ", ", & &1.email)

    if team.name == "My Team" do
      owners
    else
      "#{team.name} #{owners}"
    end
  end

  defp grace_period_status(team) do
    grace_period = team.grace_period

    case grace_period do
      nil ->
        "--"

      %{manual_lock: true, is_over: true} ->
        "Manually locked"

      %{manual_lock: true, is_over: false} ->
        "Waiting for manual lock"

      %{is_over: true} ->
        "ended"

      %{end_date: %Date{} = end_date} ->
        days_left = Date.diff(end_date, Date.utc_today())
        "#{days_left} days left"
    end
  end

  defp subscription_plan(team) do
    subscription = team.subscription

    if Subscription.Status.active?(subscription) && subscription.paddle_subscription_id do
      quota = PlausibleWeb.AuthView.subscription_quota(subscription)
      interval = PlausibleWeb.AuthView.subscription_interval(subscription)

      {:safe, ~s(<a href="#{manage_url(subscription)}">#{quota} \(#{interval}\)</a>)}
    else
      "--"
    end
  end

  defp subscription_status(team) do
    cond do
      team && team.subscription ->
        status_str =
          PlausibleWeb.SettingsView.present_subscription_status(team.subscription.status)

        if team.subscription.paddle_subscription_id do
          {:safe, ~s(<a href="#{manage_url(team.subscription)}">#{status_str}</a>)}
        else
          status_str
        end

      Plausible.Teams.on_trial?(team) ->
        "On trial"

      true ->
        "Trial expired"
    end
  end

  defp manage_url(%{paddle_subscription_id: paddle_id} = _subscription) do
    Plausible.Billing.PaddleApi.vendors_domain() <>
      "/subscriptions/customers/manage/" <> paddle_id
  end

  defp get_other_members(team) do
    team.team_memberships
    |> Enum.reject(&(&1.role == :owner))
    |> Enum.map_join(", ", fn tm -> tm.user.email <> " (#{tm.role})" end)
  end

  defp format_date(nil), do: "--"

  defp format_date(date) do
    Calendar.strftime(date, "%b %-d, %Y")
  end
end
