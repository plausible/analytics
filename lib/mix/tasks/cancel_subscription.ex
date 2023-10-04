defmodule Mix.Tasks.CancelSubscription do
  @moduledoc """
  This task is meant to replicate the behavior of cancelling
  a subscription. On production, this action is initiated by
  a Paddle webhook. Currently, only the subscription status
  is changed with that action.
  """

  use Mix.Task
  use Plausible.Repo
  alias Plausible.{Repo, Billing.Subscription}
  require Logger

  def run([paddle_subscription_id]) do
    Mix.Task.run("app.start")

    Repo.get_by!(Subscription, paddle_subscription_id: paddle_subscription_id)
    |> Subscription.changeset(%{status: "deleted"})
    |> Repo.update!()

    Logger.info("Successfully set the subscription status to 'deleted'.")
  end
end
