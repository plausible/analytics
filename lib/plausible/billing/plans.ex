defmodule Plausible.Billing.Plan do
  @moduledoc false

  @derive Jason.Encoder

  @enforce_keys ~w(kind site_limit monthly_pageview_limit team_member_limit volume monthly_product_id yearly_product_id)a
  defstruct @enforce_keys ++ [:monthly_cost, :yearly_cost]

  @type t() ::
          %__MODULE__{
            kind: atom(),
            monthly_pageview_limit: non_neg_integer(),
            site_limit: non_neg_integer(),
            team_member_limit: non_neg_integer() | :unlimited,
            volume: String.t(),
            monthly_cost: Money.t() | nil,
            yearly_cost: Money.t() | nil,
            monthly_product_id: String.t() | nil,
            yearly_product_id: String.t() | nil
          }
          | :enterprise

  def new(params) when is_map(params) do
    struct!(__MODULE__, params)
  end
end

defmodule Plausible.Billing.Plans do
  alias Plausible.Billing.Subscriptions
  use Plausible.Repo
  alias Plausible.Billing.{Subscription, Plan, EnterprisePlan}
  alias Plausible.Auth.User

  for f <- [
        :plans_v1,
        :plans_v2,
        :plans_v3,
        :plans_v4,
        :unlisted_plans_v1,
        :unlisted_plans_v2,
        :sandbox_plans
      ] do
    path = Application.app_dir(:plausible, ["priv", "#{f}.json"])

    plans_list =
      path
      |> File.read!()
      |> Jason.decode!(keys: :atoms!)
      |> Enum.map(fn raw ->
        team_member_limit =
          case raw.team_member_limit do
            number when is_integer(number) -> number
            "unlimited" -> :unlimited
            _any -> raise ArgumentError, "Failed to parse team member limit from plan JSON files"
          end

        volume = PlausibleWeb.StatsView.large_number_format(raw.monthly_pageview_limit)

        raw
        |> Map.put(:volume, volume)
        |> Map.put(:kind, String.to_atom(raw.kind))
        |> Map.put(:team_member_limit, team_member_limit)
        |> Plan.new()
      end)

    Module.put_attribute(__MODULE__, f, plans_list)

    # https://hexdocs.pm/elixir/1.15/Module.html#module-external_resource
    Module.put_attribute(__MODULE__, :external_resource, path)
  end

  @spec growth_plans_for(User.t()) :: [Plan.t()]
  @doc """
  Returns a list of growth plans available for the user to choose.

  As new versions of plans are introduced, users who were on old plans can
  still choose from old plans.
  """
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def growth_plans_for(%User{} = user) do
    user = Plausible.Users.with_subscription(user)
    v4_available = FunWithFlags.enabled?(:business_tier, for: user)
    owned_plan_id = user.subscription && user.subscription.paddle_plan_id

    cond do
      find(owned_plan_id, @plans_v1) -> @plans_v1
      find(owned_plan_id, @plans_v2) -> @plans_v2
      find(owned_plan_id, @plans_v3) -> @plans_v3
      find(owned_plan_id, plans_sandbox()) -> plans_sandbox()
      Application.get_env(:plausible, :environment) == "dev" -> plans_sandbox()
      Timex.before?(user.inserted_at, ~D[2022-01-01]) -> @plans_v2
      v4_available -> Enum.filter(@plans_v4, &(&1.kind == :growth))
      true -> @plans_v3
    end
  end

  def business_plans() do
    Enum.filter(@plans_v4, &(&1.kind == :business))
  end

  def available_plans_with_prices(%User{} = user) do
    (growth_plans_for(user) ++ business_plans())
    |> with_prices()
    |> Enum.group_by(& &1.kind)
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

  defp find(product_id, scope \\ all())

  defp find(nil, _scope), do: nil

  defp find(product_id, scope) do
    Enum.find(scope, fn plan ->
      product_id in [plan.monthly_product_id, plan.yearly_product_id]
    end)
  end

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
  def with_prices([_ | _] = plans) do
    product_ids = Enum.flat_map(plans, &[&1.monthly_product_id, &1.yearly_product_id])

    case Plausible.Billing.paddle_api().fetch_prices(product_ids) do
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

  defp get_enterprise_plan(%Subscription{} = subscription) do
    Repo.get_by(EnterprisePlan,
      user_id: subscription.user_id,
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

  @enterprise_level_usage 10_000_000
  @spec suggest(User.t(), non_neg_integer()) :: Plan.t()
  @doc """
  Returns the most appropriate plan for a user based on their usage during a
  given cycle.

  If the usage during the cycle exceeds the enterprise-level threshold, or if
  the user already belongs to an enterprise plan, it suggests the :enterprise
  plan.

  Otherwise, it recommends the plan where the cycle usage falls just under the
  plan's limit from the available options for the user.
  """
  def suggest(user, usage_during_cycle) do
    cond do
      usage_during_cycle > @enterprise_level_usage -> :enterprise
      Plausible.Auth.enterprise?(user) -> :enterprise
      true -> suggest_by_usage(user, usage_during_cycle)
    end
  end

  defp suggest_by_usage(user, usage_during_cycle) do
    user = Plausible.Users.with_subscription(user)

    available_plans =
      if business_tier?(user.subscription),
        do: business_plans(),
        else: growth_plans_for(user)

    Enum.find(available_plans, &(usage_during_cycle < &1.monthly_pageview_limit))
  end

  defp all() do
    @plans_v1 ++
      @unlisted_plans_v1 ++
      @plans_v2 ++ @unlisted_plans_v2 ++ @plans_v3 ++ @plans_v4 ++ plans_sandbox()
  end

  defp plans_sandbox() do
    case Application.get_env(:plausible, :environment) do
      "dev" -> @sandbox_plans
      _ -> []
    end
  end
end
