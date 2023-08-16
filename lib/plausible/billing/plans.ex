defmodule Plausible.Billing.Plan do
  @moduledoc false

  @derive Jason.Encoder
  @enforce_keys ~w(kind site_limit monthly_pageview_limit volume monthly_cost yearly_cost monthly_product_id yearly_product_id)a
  defstruct @enforce_keys

  @type t() ::
          %__MODULE__{
            kind: atom(),
            monthly_pageview_limit: non_neg_integer(),
            site_limit: non_neg_integer(),
            volume: String.t(),
            monthly_cost: String.t() | nil,
            yearly_cost: String.t() | nil,
            monthly_product_id: String.t() | nil,
            yearly_product_id: String.t() | nil
          }
          | :enterprise
end

defmodule Plausible.Billing.Plans do
  use Plausible.Repo

  for f <- [
        :plans_v1,
        :plans_v2,
        :plans_v3,
        :unlisted_plans_v1,
        :unlisted_plans_v2,
        :sandbox_plans
      ] do
    path = Application.app_dir(:plausible, ["priv", "#{f}.json"])

    contents =
      path
      |> File.read!()
      |> Jason.decode!(keys: :atoms!)
      |> Enum.map(
        &Map.put(
          &1,
          :volume,
          PlausibleWeb.StatsView.large_number_format(&1.monthly_pageview_limit)
        )
      )
      |> Enum.map(&Map.put(&1, :kind, String.to_atom(&1.kind)))
      |> Enum.map(&struct!(Plausible.Billing.Plan, &1))

    Module.put_attribute(__MODULE__, f, contents)
    Module.put_attribute(__MODULE__, :external_resource, path)
  end

  @spec for_user(Plausible.Auth.User.t()) :: [Plausible.Billing.Plan.t()]
  @doc """
  Returns a list of plans available for the user to choose.

  As new versions of plans are introduced, users who were on old plans can
  still choose from old plans.
  """
  def for_user(%Plausible.Auth.User{} = user) do
    user = Plausible.Users.with_subscription(user)

    cond do
      find(user.subscription, @plans_v1) -> @plans_v1
      find(user.subscription, @plans_v2) -> @plans_v2
      find(user.subscription, @plans_v3) -> @plans_v3
      find(user.subscription, plans_sandbox()) -> plans_sandbox()
      Application.get_env(:plausible, :environment) == "dev" -> plans_sandbox()
      Timex.before?(user.inserted_at, ~D[2022-01-01]) -> @plans_v2
      true -> @plans_v3
    end
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

  @spec find(String.t() | Plausible.Billing.Subscription.t(), [Plausible.Billing.Plan.t()]) ::
          Plausible.Billing.Plan.t() | nil
  @spec find(nil, any()) :: nil
  @doc """
  Finds a plan by product ID.

  Returns nil when plan can't be found.
  """
  def find(product_id_or_subscription, scope \\ all())

  def find(nil, _scope) do
    nil
  end

  def find(%Plausible.Billing.Subscription{} = subscription, scope) do
    find(subscription.paddle_plan_id, scope)
  end

  def find(product_id, scope) do
    Enum.find(scope, fn plan ->
      product_id in [plan.monthly_product_id, plan.yearly_product_id]
    end)
  end

  @limit_sites_since ~D[2021-05-05]
  @spec site_limit(Plausible.Auth.User.t()) :: non_neg_integer() | :unlimited
  @doc """
  Returns the limit of sites a user can have.

  For enterprise customers, returns :unlimited. The site limit is checked in a
  background job so as to avoid service disruption.
  """
  def site_limit(user) do
    cond do
      Application.get_env(:plausible, :is_selfhost) -> :unlimited
      user.email in Application.get_env(:plausible, :site_limit_exempt) -> :unlimited
      Timex.before?(user.inserted_at, @limit_sites_since) -> :unlimited
      true -> get_site_limit_from_plan(user)
    end
  end

  @site_limit_for_trials 50
  @site_limit_for_free_10k 50
  defp get_site_limit_from_plan(user) do
    user = Plausible.Users.with_subscription(user)

    case get_subscription_plan(user.subscription) do
      %Plausible.Billing.EnterprisePlan{} -> :unlimited
      %Plausible.Billing.Plan{site_limit: site_limit} -> site_limit
      :free_10k -> @site_limit_for_free_10k
      nil -> @site_limit_for_trials
    end
  end

  defp get_subscription_plan(subscription) do
    if subscription && subscription.paddle_plan_id == "free_10k" do
      :free_10k
    else
      find(subscription) || get_enterprise_plan(subscription)
    end
  end

  def subscription_interval(subscription) do
    case get_subscription_plan(subscription) do
      %Plausible.Billing.EnterprisePlan{billing_interval: interval} ->
        interval

      %Plausible.Billing.Plan{} = plan ->
        if plan.monthly_product_id == subscription.paddle_plan_id do
          "monthly"
        else
          "yearly"
        end

      _any ->
        "N/A"
    end
  end

  @spec allowance(Plausible.Billing.Subscription.t()) :: non_neg_integer() | nil
  def allowance(subscription) do
    case get_subscription_plan(subscription) do
      %Plausible.Billing.EnterprisePlan{monthly_pageview_limit: limit} ->
        limit

      %Plausible.Billing.Plan{monthly_pageview_limit: limit} ->
        limit

      :free_10k ->
        10_000

      _any ->
        Sentry.capture_message("Unknown allowance for plan",
          extra: %{paddle_plan_id: subscription.paddle_plan_id}
        )
    end
  end

  defp get_enterprise_plan(nil), do: nil

  defp get_enterprise_plan(%Plausible.Billing.Subscription{} = subscription) do
    Repo.get_by(Plausible.Billing.EnterprisePlan,
      user_id: subscription.user_id,
      paddle_plan_id: subscription.paddle_plan_id
    )
  end

  @enterprise_level_usage 10_000_000
  @spec suggest(Plausible.Auth.User.t(), non_neg_integer()) :: Plausible.Billing.Plan.t()
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
      true -> Enum.find(for_user(user), &(usage_during_cycle < &1.monthly_pageview_limit))
    end
  end

  defp all() do
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
