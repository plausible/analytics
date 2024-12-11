defmodule Plausible.Auth.UserAdmin do
  use Plausible.Repo
  use Plausible
  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.Subscription

  def custom_index_query(_conn, _schema, query) do
    subscripton_q = from(s in Plausible.Billing.Subscription, order_by: [desc: s.inserted_at])
    from(r in query, preload: [my_team: [subscription: ^subscripton_q]])
  end

  def custom_show_query(_conn, _schema, query) do
    from(u in query,
      left_join: t in assoc(u, :my_team),
      select: %{
        u
        | trial_expiry_date: t.trial_expiry_date,
          allow_next_upgrade_override: t.allow_next_upgrade_override,
          accept_traffic_until: t.accept_traffic_until
      }
    )
  end

  def form_fields(_) do
    [
      name: nil,
      email: nil,
      previous_email: nil,
      trial_expiry_date: %{
        help_text: "Change will also update Accept Traffic Until date"
      },
      allow_next_upgrade_override: nil,
      accept_traffic_until: %{
        help_text: "Change will take up to 15 minutes to propagate"
      },
      notes: %{type: :textarea, rows: 6}
    ]
  end

  def update(_conn, changeset) do
    my_team = Repo.preload(changeset.data, :my_team).my_team

    team_changed_params =
      [:trial_expiry_date, :allow_next_upgrade_override, :accept_traffic_until]
      |> Enum.map(&{&1, Ecto.Changeset.get_change(changeset, &1, :no_change)})
      |> Enum.reject(fn {_, val} -> val == :no_change end)
      |> Map.new()

    with {:ok, user} <- Repo.update(changeset) do
      cond do
        my_team && map_size(team_changed_params) > 0 ->
          my_team
          |> Plausible.Teams.Team.crm_sync_changeset(team_changed_params)
          |> Repo.update!()

        team_changed_params[:trial_expiry_date] ->
          {:ok, team} = Plausible.Teams.get_or_create(user)

          team
          |> Plausible.Teams.Team.crm_sync_changeset(team_changed_params)
          |> Repo.update!()

        true ->
          :ignore
      end

      {:ok, user}
    end
  end

  def delete(_conn, %{data: user}) do
    Plausible.Auth.delete_user(user)
  end

  def index(_) do
    [
      name: nil,
      email: nil,
      inserted_at: %{name: "Created at", value: &format_date(&1.inserted_at)},
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

  def resource_actions(_) do
    [
      unlock: %{
        name: "Unlock",
        action: fn _, user -> unlock(user) end
      },
      lock: %{
        name: "Lock",
        action: fn _, user -> lock(user) end
      },
      reset_2fa: %{
        name: "Reset 2FA",
        action: fn _, user -> disable_2fa(user) end
      }
    ]
  end

  defp lock(user) do
    user = Repo.preload(user, :my_team)

    if user.my_team && user.my_team.grace_period do
      Plausible.Billing.SiteLocker.set_lock_status_for(user.my_team, true)
      Plausible.Teams.end_grace_period(user.my_team)
      {:ok, user}
    else
      {:error, user, "No active grace period on this user"}
    end
  end

  defp unlock(user) do
    user = Repo.preload(user, :my_team)

    if user.my_team && user.my_team.grace_period do
      Plausible.Teams.remove_grace_period(user.my_team)
      Plausible.Billing.SiteLocker.set_lock_status_for(user.my_team, false)
      {:ok, user}
    else
      {:error, user, "No active grace period on this user"}
    end
  end

  def disable_2fa(user) do
    Plausible.Auth.TOTP.force_disable(user)
  end

  defp grace_period_status(user) do
    grace_period = user.my_team && user.my_team.grace_period

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

  defp subscription_plan(user) do
    subscription = user.my_team && user.my_team.subscription

    if Subscription.Status.active?(subscription) && subscription.paddle_subscription_id do
      quota = PlausibleWeb.AuthView.subscription_quota(subscription)
      interval = PlausibleWeb.AuthView.subscription_interval(subscription)

      {:safe, ~s(<a href="#{manage_url(subscription)}">#{quota} \(#{interval}\)</a>)}
    else
      "--"
    end
  end

  defp subscription_status(user) do
    team = user.my_team

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

  defp format_date(nil), do: "--"

  defp format_date(date) do
    Calendar.strftime(date, "%b %-d, %Y")
  end
end
