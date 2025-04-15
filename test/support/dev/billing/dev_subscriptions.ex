defmodule Plausible.Billing.DevSubscriptions do
  @moduledoc """
  Module for conveniently handling subscriptions in the :dev environment.
  """

  alias Plausible.{Repo, Billing}

  def create_after_1s(team_id, plan_id) do
    Task.start(fn ->
      Process.sleep(1000)
      create(team_id, plan_id)
    end)
  end

  def create(team_id, plan_id, opts \\ []) do
    plan = Billing.Plans.find(plan_id)

    if plan do
      next_bill_date =
        Date.utc_today()
        |> Date.shift(if plan_id == plan.monthly_product_id, do: [month: 1], else: [year: 1])

      if Keyword.get(opts, :clean_existing, true) do
        delete(team_id)
      end

      %{
        "event_time" => to_string(NaiveDateTime.utc_now(:second)),
        "alert_name" => "subscription_created",
        "passthrough" => "ee:true;user:0;team:#{team_id}",
        "email" => "",
        "subscription_id" => Ecto.UUID.generate(),
        "subscription_plan_id" => plan_id,
        "update_url" => "update",
        "cancel_url" =>
          PlausibleWeb.Router.Helpers.dev_subscription_path(PlausibleWeb.Endpoint, :cancel_form),
        "status" => "active",
        "next_bill_date" => next_bill_date,
        "unit_price" => "#{to_string(Plausible.Billing.DevPaddleApiMock.prices()[plan_id])}.00",
        "currency" => "EUR"
      }
      |> Plausible.Billing.subscription_created()

      {:ok, Repo.reload(get_team_subscription(team_id))}
    else
      {:error, "Plan with id '#{plan_id}' not found."}
    end
  end

  def delete(team_id) do
    case get_team_subscription(team_id) do
      nil -> {:error, :no_subscription}
      subscription -> Repo.delete(subscription)
    end
  end

  def cancel(team_id, opts \\ []) do
    set_expired? = Keyword.get(opts, :set_expired?, false)

    if subscription = get_team_subscription(team_id) do
      %{"subscription_id" => subscription.paddle_subscription_id, "status" => "deleted"}
      |> Billing.subscription_cancelled()

      subscription = Repo.reload!(subscription)

      if set_expired? do
        subscription
        |> Ecto.Changeset.change(%{next_bill_date: Date.utc_today() |> Date.add(-1)})
        |> Repo.update()
      else
        {:ok, subscription}
      end
    else
      {:error, :no_subscription}
    end
  end

  defp get_team_subscription(team_id) do
    Plausible.Teams.Team
    |> Plausible.Repo.get(team_id)
    |> Plausible.Teams.with_subscription()
    |> Map.get(:subscription)
  end
end
