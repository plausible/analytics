defmodule Mix.Tasks.PullSandboxSubscription do
  use Mix.Task
  use Plausible.Repo
  alias Plausible.{Repo, Auth.User, Billing.Subscription}
  require Logger

  # Steps to create a subscription in dev environment
  #
  # 1) Subscribe to a sandbox plan in the UI > User Settings. Instructions:
  #    https://developer.paddle.com/getting-started/ZG9jOjIxODY4NjYx-sandbox
  #
  # 2) find the created subscription_ID here:
  #    https://sandbox-vendors.paddle.com/subscriptions/customers
  #
  # 3) run from command line:
  #    mix pull_sandbox_subscription <subscription_ID>

  @headers [
    {"Content-type", "application/json"},
    {"Accept", "application/json"}
  ]

  def run([paddle_subscription_id]) do
    Mix.Task.run("app.start")

    config = Application.get_env(:plausible, :paddle)

    endpoint = Plausible.Billing.PaddleApi.vendors_domain() <> "/api/2.0/subscription/users"

    params = %{
      vendor_id: config[:vendor_id],
      vendor_auth_code: config[:vendor_auth_code],
      subscription_id: paddle_subscription_id
    }

    case HTTPoison.post(endpoint, Jason.encode!(params), @headers) do
      {:ok, response} ->
        body = Jason.decode!(response.body)

        if body["success"] do
          res = body["response"] |> List.first()
          user = Repo.get_by!(User, email: res["user_email"])
          {:ok, team} = Plausible.Teams.get_or_create(user)

          subscription = %{
            paddle_subscription_id: res["subscription_id"] |> to_string(),
            paddle_plan_id: res["plan_id"] |> to_string(),
            cancel_url: res["cancel_url"],
            update_url: res["update_url"],
            team_id: team.id,
            status: res["state"],
            last_bill_date: res["last_payment"]["date"],
            next_bill_date: res["next_payment"]["date"],
            next_bill_amount: res["next_payment"]["amount"] |> to_string(),
            currency_code: res["next_payment"]["currency"]
          }

          Subscription.changeset(%Subscription{}, subscription)
          |> Repo.insert!()

          Logger.notice("Subscription created for user #{user.id} (#{user.email})")
        else
          Logger.error(body["error"])
        end

      {:error, reason} ->
        Logger.error(reason)
    end
  end
end
