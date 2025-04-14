defmodule Plausible.Billing.Plans do
  alias Plausible.Billing.Subscriptions
  use Plausible.Repo
  alias Plausible.Billing.{Subscription, Plan, EnterprisePlan}
  alias Plausible.Teams

  for f <- [
        :legacy_plans,
        :plans_v1,
        :plans_v2,
        :plans_v3,
        :plans_v4,
        :sandbox_plans
      ] do
    path = Application.app_dir(:plausible, ["priv", "#{f}.json"])

    plans_list =
      for attrs <- path |> File.read!() |> Jason.decode!() do
        %Plan{} |> Plan.changeset(attrs) |> Ecto.Changeset.apply_action!(nil)
      end

    Module.put_attribute(__MODULE__, f, plans_list)

    # https://hexdocs.pm/elixir/1.15/Module.html#module-external_resource
    Module.put_attribute(__MODULE__, :external_resource, path)
  end

  @spec growth_plans_for(Subscription.t()) :: [Plan.t()]
  @doc """
  Returns a list of growth plans available for the subscription to choose.

  As new versions of plans are introduced, subscriptions which were on old plans can
  still choose from old plans.
  """
  def growth_plans_for(subscription) do
    owned_plan = get_regular_plan(subscription)

    cond do
      Application.get_env(:plausible, :environment) == "staging" -> @sandbox_plans
      is_nil(owned_plan) -> @plans_v4
      subscription && Subscriptions.expired?(subscription) -> @plans_v4
      owned_plan.kind == :business -> @plans_v4
      owned_plan.generation == 1 -> @plans_v1 |> drop_high_plans(owned_plan)
      owned_plan.generation == 2 -> @plans_v2 |> drop_high_plans(owned_plan)
      owned_plan.generation == 3 -> @plans_v3
      owned_plan.generation == 4 -> @plans_v4
    end
    |> Enum.filter(&(&1.kind == :growth))
  end

  def business_plans_for(subscription) do
    owned_plan = get_regular_plan(subscription)

    cond do
      Application.get_env(:plausible, :environment) == "staging" -> @sandbox_plans
      subscription && Subscriptions.expired?(subscription) -> @plans_v4
      owned_plan && owned_plan.generation < 4 -> @plans_v3
      true -> @plans_v4
    end
    |> Enum.filter(&(&1.kind == :business))
  end

  def available_plans_for(subscription, opts \\ []) do
    plans = growth_plans_for(subscription) ++ business_plans_for(subscription)

    plans =
      if Keyword.get(opts, :with_prices) do
        customer_ip = Keyword.fetch!(opts, :customer_ip)
        with_prices(plans, customer_ip)
      else
        plans
      end

    Enum.group_by(plans, & &1.kind)
  end

  @high_legacy_volumes [20_000_000, 50_000_000]
  defp drop_high_plans(plans, %Plan{monthly_pageview_limit: current_volume} = _owned) do
    plans
    |> Enum.reject(fn %Plan{monthly_pageview_limit: plan_volume} ->
      plan_volume in @high_legacy_volumes and current_volume < plan_volume
    end)
  end

  @spec yearly_product_ids() :: [String.t()]
  @doc """
  List yearly plans product IDs.
  """
  def yearly_product_ids do
    for %{yearly_product_id: yearly_product_id} <- all(),
        is_binary(yearly_product_id),
        do: yearly_product_id
  end

  def find(nil), do: nil

  def find(product_id) do
    Enum.find(all(), fn plan ->
      product_id in [plan.monthly_product_id, plan.yearly_product_id]
    end)
  end

  @spec get_subscription_plan(nil | Subscription.t()) ::
          nil | :free_10k | Plan.t() | EnterprisePlan.t()
  def get_subscription_plan(nil), do: nil

  def get_subscription_plan(subscription) do
    if subscription.paddle_plan_id == "free_10k" do
      :free_10k
    else
      get_regular_plan(subscription) || get_enterprise_plan(subscription)
    end
  end

  def subscription_interval(subscription) do
    case get_subscription_plan(subscription) do
      %EnterprisePlan{billing_interval: interval} ->
        interval

      %Plan{} = plan ->
        if plan.monthly_product_id == subscription.paddle_plan_id do
          "monthly"
        else
          "yearly"
        end

      _any ->
        "N/A"
    end
  end

  @doc """
  This function takes a list of plans as an argument, gathers all product
  IDs in a single list, and makes an API call to Paddle. After a successful
  response, fills in the `monthly_cost` and `yearly_cost` fields for each
  given plan and returns the new list of plans with completed information.
  """
  def with_prices([_ | _] = plans, customer_ip \\ "127.0.0.1") do
    product_ids = Enum.flat_map(plans, &[&1.monthly_product_id, &1.yearly_product_id])

    case Plausible.Billing.paddle_api().fetch_prices(product_ids, customer_ip) do
      {:ok, prices} ->
        Enum.map(plans, fn plan ->
          plan
          |> Map.put(:monthly_cost, prices[plan.monthly_product_id])
          |> Map.put(:yearly_cost, prices[plan.yearly_product_id])
        end)

      {:error, :api_error} ->
        plans
    end
  end

  def get_regular_plan(subscription, opts \\ [])

  def get_regular_plan(nil, _opts), do: nil

  def get_regular_plan(%Subscription{} = subscription, opts) do
    if Keyword.get(opts, :only_non_expired) && Subscriptions.expired?(subscription) do
      nil
    else
      find(subscription.paddle_plan_id)
    end
  end

  def get_price_for(%EnterprisePlan{paddle_plan_id: product_id}, customer_ip) do
    case Plausible.Billing.paddle_api().fetch_prices([product_id], customer_ip) do
      {:ok, prices} -> Map.fetch!(prices, product_id)
      {:error, :api_error} -> nil
    end
  end

  defp get_enterprise_plan(%Subscription{} = subscription) do
    Repo.get_by(EnterprisePlan,
      team_id: subscription.team_id,
      paddle_plan_id: subscription.paddle_plan_id
    )
  end

  def business_tier?(nil), do: false

  def business_tier?(%Subscription{} = subscription) do
    case get_subscription_plan(subscription) do
      %Plan{kind: :business} -> true
      _ -> false
    end
  end

  @doc """
  Returns the most appropriate plan for a team based on its usage during a
  given cycle.

  If the usage during the cycle exceeds the enterprise-level threshold, or if
  the team already has an enterprise plan, it suggests the :enterprise
  plan.

  Otherwise, it recommends the plan where the cycle usage falls just under the
  plan's limit from the available options for the team.
  """
  @enterprise_level_usage 10_000_000
  @spec suggest(Teams.Team.t(), non_neg_integer()) :: Plan.t()
  def suggest(team, usage_during_cycle) do
    cond do
      usage_during_cycle > @enterprise_level_usage ->
        :enterprise

      Teams.Billing.enterprise_configured?(team) ->
        :enterprise

      true ->
        subscription = Teams.Billing.get_subscription(team)
        suggest_by_usage(subscription, usage_during_cycle)
    end
  end

  def suggest_by_usage(subscription, usage_during_cycle) do
    available_plans =
      if business_tier?(subscription),
        do: business_plans_for(subscription),
        else: growth_plans_for(subscription)

    Enum.find(available_plans, &(usage_during_cycle < &1.monthly_pageview_limit))
  end

  def all() do
    @legacy_plans ++ @plans_v1 ++ @plans_v2 ++ @plans_v3 ++ @plans_v4 ++ sandbox_plans()
  end

  defp sandbox_plans() do
    if Application.get_env(:plausible, :environment) in ["dev", "staging"] do
      @sandbox_plans
    else
      []
    end
  end
end
