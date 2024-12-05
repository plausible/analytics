defmodule PlausibleWeb.Live.ChoosePlan do
  @moduledoc """
  LiveView for upgrading to a plan, or changing an existing plan.
  """
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  require Plausible.Billing.Subscription.Status

  alias PlausibleWeb.Components.Billing.{PlanBox, PlanBenefits, Notice, PageviewSlider}
  alias Plausible.Billing.{Plans, Quota}

  @contact_link "https://plausible.io/contact"
  @billing_faq_link "https://plausible.io/docs/billing"

  def mount(_params, %{"remote_ip" => remote_ip}, socket) do
    socket =
      socket
      |> assign_new(:pending_ownership_site_ids, fn %{current_user: current_user} ->
        current_user.email
        |> Plausible.Teams.Adapter.Read.Ownership.all_pending_site_transfers(current_user)
        |> Enum.map(& &1.site_id)
      end)
      |> assign_new(:usage, fn %{
                                 current_user: current_user,
                                 pending_ownership_site_ids: pending_ownership_site_ids
                               } ->
        Plausible.Teams.Adapter.Read.Billing.quota_usage(current_user,
          with_features: true,
          pending_ownership_site_ids: pending_ownership_site_ids
        )
      end)
      |> assign_new(:subscription, fn %{current_user: current_user} ->
        Plausible.Teams.Adapter.Read.Billing.get_subscription(current_user)
      end)
      |> assign_new(:owned_plan, fn %{subscription: subscription} ->
        Plans.get_regular_plan(subscription, only_non_expired: true)
      end)
      |> assign_new(:owned_tier, fn %{owned_plan: owned_plan} ->
        if owned_plan, do: Map.get(owned_plan, :kind), else: nil
      end)
      |> assign_new(:current_interval, fn %{subscription: subscription} ->
        current_user_subscription_interval(subscription)
      end)
      |> assign_new(:available_plans, fn %{subscription: subscription} ->
        Plans.available_plans_for(subscription, with_prices: true, customer_ip: remote_ip)
      end)
      |> assign_new(:recommended_tier, fn %{usage: usage, available_plans: available_plans} ->
        highest_growth_plan = List.last(available_plans.growth)
        highest_business_plan = List.last(available_plans.business)
        Quota.suggest_tier(usage, highest_growth_plan, highest_business_plan)
      end)
      |> assign_new(:available_volumes, fn %{available_plans: available_plans} ->
        get_available_volumes(available_plans)
      end)
      |> assign_new(:selected_volume, fn %{
                                           usage: usage,
                                           available_volumes: available_volumes
                                         } ->
        default_selected_volume(usage.monthly_pageviews, available_volumes)
      end)
      |> assign_new(:selected_interval, fn %{current_interval: current_interval} ->
        current_interval || :monthly
      end)
      |> assign_new(:selected_growth_plan, fn %{
                                                available_plans: available_plans,
                                                selected_volume: selected_volume
                                              } ->
        get_plan_by_volume(available_plans.growth, selected_volume)
      end)
      |> assign_new(:selected_business_plan, fn %{
                                                  available_plans: available_plans,
                                                  selected_volume: selected_volume
                                                } ->
        get_plan_by_volume(available_plans.business, selected_volume)
      end)

    {:ok, socket}
  end

  def render(assigns) do
    growth_plan_to_render =
      assigns.selected_growth_plan || List.last(assigns.available_plans.growth)

    business_plan_to_render =
      assigns.selected_business_plan || List.last(assigns.available_plans.business)

    growth_benefits = PlanBenefits.for_growth(growth_plan_to_render)
    business_benefits = PlanBenefits.for_business(business_plan_to_render, growth_benefits)
    enterprise_benefits = PlanBenefits.for_enterprise(business_benefits)

    assigns =
      assigns
      |> assign(:growth_plan_to_render, growth_plan_to_render)
      |> assign(:business_plan_to_render, business_plan_to_render)
      |> assign(:growth_benefits, growth_benefits)
      |> assign(:business_benefits, business_benefits)
      |> assign(:enterprise_benefits, enterprise_benefits)

    ~H"""
    <div class="pt-1 pb-12 sm:pb-16 text-gray-900 dark:text-gray-100">
      <div class="mx-auto max-w-7xl px-6 lg:px-20">
        <Notice.pending_site_ownerships_notice
          class="pb-6"
          pending_ownership_count={length(@pending_ownership_site_ids)}
        />
        <Notice.subscription_past_due class="pb-6" subscription={@subscription} />
        <Notice.subscription_paused class="pb-6" subscription={@subscription} />
        <Notice.upgrade_ineligible :if={not Quota.eligible_for_upgrade?(@usage)} />
        <div class="mx-auto max-w-4xl text-center">
          <p class="text-4xl font-bold tracking-tight lg:text-5xl">
            <%= if @owned_plan,
              do: "Change subscription plan",
              else: "Upgrade your account" %>
          </p>
        </div>
        <div class="mt-12 flex flex-col gap-8 lg:flex-row items-center lg:items-baseline">
          <.interval_picker selected_interval={@selected_interval} />
          <PageviewSlider.render
            selected_volume={@selected_volume}
            available_volumes={@available_volumes}
          />
        </div>
        <div class="mt-6 isolate mx-auto grid max-w-md grid-cols-1 gap-8 lg:mx-0 lg:max-w-none lg:grid-cols-3">
          <PlanBox.standard
            kind={:growth}
            owned={@owned_tier == :growth}
            recommended={@recommended_tier == :growth}
            plan_to_render={@growth_plan_to_render}
            benefits={@growth_benefits}
            available={!!@selected_growth_plan}
            {assigns}
          />
          <PlanBox.standard
            kind={:business}
            owned={@owned_tier == :business}
            recommended={@recommended_tier == :business}
            plan_to_render={@business_plan_to_render}
            benefits={@business_benefits}
            available={!!@selected_business_plan}
            {assigns}
          />
          <PlanBox.enterprise
            benefits={@enterprise_benefits}
            recommended={@recommended_tier == :custom}
          />
        </div>
        <p class="mx-auto mt-8 max-w-2xl text-center text-lg leading-8 text-gray-600 dark:text-gray-400">
          <.render_usage pageview_usage={@usage.monthly_pageviews} />
        </p>
        <.pageview_limit_notice :if={!@owned_plan} />
        <.help_links />
      </div>
    </div>
    <PlausibleWeb.Components.Billing.paddle_script />
    """
  end

  defp render_usage(assigns) do
    case assigns.pageview_usage do
      %{last_30_days: _} ->
        ~H"""
        You have used
        <b><%= PlausibleWeb.AuthView.delimit_integer(@pageview_usage.last_30_days.total) %></b> billable pageviews in the last 30 days
        """

      %{last_cycle: _} ->
        ~H"""
        You have used
        <b><%= PlausibleWeb.AuthView.delimit_integer(@pageview_usage.last_cycle.total) %></b> billable pageviews in the last billing cycle
        """
    end
  end

  def handle_event("set_interval", %{"interval" => interval}, socket) do
    new_interval =
      case interval do
        "yearly" -> :yearly
        "monthly" -> :monthly
      end

    {:noreply, assign(socket, selected_interval: new_interval)}
  end

  def handle_event("slide", %{"slider" => index}, socket) do
    index = String.to_integer(index)
    %{available_plans: available_plans, available_volumes: available_volumes} = socket.assigns

    new_volume =
      if index == length(available_volumes) do
        :enterprise
      else
        Enum.at(available_volumes, index)
      end

    {:noreply,
     assign(socket,
       selected_volume: new_volume,
       selected_growth_plan: get_plan_by_volume(available_plans.growth, new_volume),
       selected_business_plan: get_plan_by_volume(available_plans.business, new_volume)
     )}
  end

  defp default_selected_volume(pageview_usage, available_volumes) do
    total =
      case pageview_usage do
        %{last_30_days: usage} -> usage.total
        %{last_cycle: usage} -> usage.total
      end

    Enum.find(available_volumes, &(total < &1)) || :enterprise
  end

  defp current_user_subscription_interval(subscription) do
    case Plans.subscription_interval(subscription) do
      "yearly" -> :yearly
      "monthly" -> :monthly
      _ -> nil
    end
  end

  defp get_plan_by_volume(_, :enterprise), do: nil

  defp get_plan_by_volume(plans, volume) do
    Enum.find(plans, &(&1.monthly_pageview_limit == volume))
  end

  defp interval_picker(assigns) do
    ~H"""
    <div class="lg:flex-1 lg:order-3 lg:justify-end flex">
      <div class="relative">
        <.two_months_free />
        <fieldset class="grid grid-cols-2 gap-x-1 rounded-full bg-white dark:bg-gray-700 p-1 text-center text-sm font-semibold leading-5 shadow dark:ring-gray-600">
          <label
            class={"cursor-pointer rounded-full px-2.5 py-1 text-gray-900 dark:text-white #{if @selected_interval == :monthly, do: "bg-indigo-600 text-white"}"}
            phx-click="set_interval"
            phx-value-interval="monthly"
          >
            <input type="radio" name="frequency" value="monthly" class="sr-only" />
            <span>Monthly</span>
          </label>
          <label
            class={"cursor-pointer rounded-full px-2.5 py-1 text-gray-900 dark:text-white #{if @selected_interval == :yearly, do: "bg-indigo-600 text-white"}"}
            phx-click="set_interval"
            phx-value-interval="yearly"
          >
            <input type="radio" name="frequency" value="yearly" class="sr-only" />
            <span>Yearly</span>
          </label>
        </fieldset>
      </div>
    </div>
    """
  end

  def two_months_free(assigns) do
    ~H"""
    <span class="absolute -right-5 -top-4 whitespace-no-wrap w-max px-2.5 py-0.5 rounded-full text-xs font-medium leading-4 bg-yellow-100 border border-yellow-300 text-yellow-700">
      2 months free
    </span>
    """
  end

  defp pageview_limit_notice(assigns) do
    ~H"""
    <div class="mt-12 mx-auto mt-6 max-w-2xl">
      <dt>
        <p class="w-full text-center text-gray-900 dark:text-gray-100">
          <span class="text-center font-semibold leading-7">
            What happens if I go over my page views limit?
          </span>
        </p>
      </dt>
      <dd class="mt-3">
        <div class="text-justify leading-7 block text-gray-600 dark:text-gray-100">
          You will never be charged extra for an occasional traffic spike. There are no surprise fees and your card will never be charged unexpectedly.               If your page views exceed your plan for two consecutive months, we will contact you to upgrade to a higher plan for the following month. You will have two weeks to make a decision. You can decide to continue with a higher plan or to cancel your account at that point.
        </div>
      </dd>
    </div>
    """
  end

  defp help_links(assigns) do
    ~H"""
    <div class="mt-8 text-center">
      Questions? <a class="text-indigo-600" href={contact_link()}>Contact us</a>
      or see <a class="text-indigo-600" href={billing_faq_link()}>billing FAQ</a>
    </div>
    """
  end

  defp get_available_volumes(%{business: business_plans, growth: growth_plans}) do
    growth_volumes = Enum.map(growth_plans, & &1.monthly_pageview_limit)
    business_volumes = Enum.map(business_plans, & &1.monthly_pageview_limit)

    (growth_volumes ++ business_volumes)
    |> Enum.uniq()
  end

  defp contact_link(), do: @contact_link

  defp billing_faq_link(), do: @billing_faq_link
end
