defmodule Mix.Tasks.CancelSubscription do
  @moduledoc """
  This task is meant to replicate the behavior of cancelling
  a subscription. On production, this action is initiated by
  a Paddle webhook. Currently, only the subscription status
  is changed with that action.
  """

  use Mix.Task
  use Plausible.Repo
  require Plausible.Billing.Subscription.Status
  require Logger
  alias Plausible.{Repo, Billing.Subscription}

  def run([paddle_subscription_id]) do
    Mix.Task.run("app.start")

    Repo.get_by!(Subscription, paddle_subscription_id: paddle_subscription_id)
    |> Subscription.changeset(%{status: Subscription.Status.deleted()})
    |> Repo.update!()

    Logger.info("Successfully set the subscription status to #{Subscription.Status.deleted()}")
  end
end
