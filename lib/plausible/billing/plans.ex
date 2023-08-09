defmodule Plausible.Billing.Plans do
  use Plausible.Repo

  for f <- [:plans_v1, :plans_v2, :plans_v3] do
    contents =
      :plausible
      |> Application.app_dir(["priv", "#{f}.json"])
      |> File.read!()
      |> Jason.decode!(keys: :atoms)

    Module.put_attribute(__MODULE__, f, contents)
  end

  @unlisted_plans_v1 [%{limit: 150_000_000, yearly_product_id: "648089", yearly_cost: "$4800"}]
  @unlisted_plans_v2 [%{limit: 10_000_000, monthly_product_id: "655350", monthly_cost: "$250"}]

  @sandbox_plans [
    %{
      limit: 10_000,
      monthly_product_id: "19878",
      yearly_product_id: "20127",
      monthly_cost: "$6",
      yearly_cost: "$60"
    },
    %{
      limit: 100_000,
      monthly_product_id: "20657",
      yearly_product_id: "20658",
      monthly_cost: "$12.34",
      yearly_cost: "$120.34"
    }
  ]

  @type plan() ::
          %{
            limit: non_neg_integer(),
            monthly_product_id: String.t(),
            yearly_product_id: String.t(),
            monthly_cost: String.t(),
            yearly_cost: String.t()
          }
          | :enterprise

  @spec plans_for(Plausible.Auth.User.t()) :: [plan()]
  @doc """
  Returns a list of plans available for the user to choose.

  As new versions of plans are introduced, users who were on old plans can
  still choose from old plans.
  """
  def plans_for(user) do
    user = Plausible.Users.with_subscription(user)

    raw_plans =
      cond do
        find(user.subscription, @plans_v1) -> @plans_v1
        find(user.subscription, @plans_v2) -> @plans_v2
        find(user.subscription, @plans_v3) -> @plans_v3
        find(user.subscription, plans_sandbox()) -> plans_sandbox()
        Application.get_env(:plausible, :environment) == "dev" -> plans_sandbox()
        Timex.before?(user.inserted_at, ~D[2022-01-01]) -> @plans_v2
        true -> @plans_v3
      end

    Enum.map(raw_plans, fn plan ->
      Map.put(plan, :volume, PlausibleWeb.StatsView.large_number_format(plan.limit))
    end)
  end

  @spec all_yearly_plan_ids() :: [String.t()]
  @doc """
  List yearly plans product IDs.
  """
  def all_yearly_plan_ids do
    Enum.map(all_plans(), fn plan -> plan[:yearly_product_id] end)
  end

  @spec find(String.t() | Plausible.Billing.Subscription.t(), [plan()]) :: plan() | nil
  @spec find(nil, any()) :: nil
  @doc """
  Finds a plan by product ID.

  Returns nil when plan can't be found.
  """
  def find(product_id_or_subscription, scope \\ all_plans())

  def find(nil, _scope) do
    nil
  end

  def find(%Plausible.Billing.Subscription{} = subscription, scope) do
    find(subscription.paddle_plan_id, scope)
  end

  def find(product_id, scope) do
    Enum.find(scope, fn plan ->
      product_id in [plan[:monthly_product_id], plan[:yearly_product_id]]
    end)
  end

  def subscription_interval(%Plausible.Billing.Subscription{paddle_plan_id: "free_10k"}),
    do: "N/A"

  def subscription_interval(subscription) do
    case find(subscription.paddle_plan_id) do
      nil ->
        enterprise_plan = get_enterprise_plan(subscription)

        enterprise_plan && enterprise_plan.billing_interval

      plan ->
        if subscription.paddle_plan_id == plan[:monthly_product_id] do
          "monthly"
        else
          "yearly"
        end
    end
  end

  def allowance(%Plausible.Billing.Subscription{paddle_plan_id: "free_10k"}), do: 10_000

  def allowance(subscription) do
    found = find(subscription.paddle_plan_id)

    if found do
      Map.fetch!(found, :limit)
    else
      enterprise_plan = get_enterprise_plan(subscription)

      if enterprise_plan do
        enterprise_plan.monthly_pageview_limit
      else
        Sentry.capture_message("Unknown allowance for plan",
          extra: %{
            paddle_plan_id: subscription.paddle_plan_id
          }
        )
      end
    end
  end

  defp get_enterprise_plan(%Plausible.Billing.Subscription{} = subscription) do
    Repo.get_by(Plausible.Billing.EnterprisePlan,
      user_id: subscription.user_id,
      paddle_plan_id: subscription.paddle_plan_id
    )
  end

  @enterprise_level_usage 10_000_000
  @spec suggested_plan(Plausible.Auth.User.t(), non_neg_integer()) :: plan()
  @doc """
  Returns the most appropriate plan for a user based on their usage during a 
  given cycle.

  If the usage during the cycle exceeds the enterprise-level threshold, or if 
  the user already belongs to an enterprise plan, it suggests the :enterprise 
  plan.

  Otherwise, it recommends the plan where the cycle usage falls just under the 
  plan's limit from the available options for the user.
  """
  def suggested_plan(user, usage_during_cycle) do
    cond do
      usage_during_cycle > @enterprise_level_usage -> :enterprise
      Plausible.Auth.enterprise?(user) -> :enterprise
      true -> Enum.find(plans_for(user), fn plan -> usage_during_cycle < plan[:limit] end)
    end
  end

  defp all_plans() do
    @plans_v1 ++
      @unlisted_plans_v1 ++ @plans_v2 ++ @unlisted_plans_v2 ++ @plans_v3 ++ plans_sandbox()
  end

  defp plans_sandbox() do
    case Application.get_env(:plausible, :environment) do
      "dev" -> @sandbox_plans
      _ -> []
    end
  end
end
