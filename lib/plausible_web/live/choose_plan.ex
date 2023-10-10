defmodule PlausibleWeb.Live.ChoosePlan do
  @moduledoc """
  LiveView for upgrading to a plan, or changing an existing plan.
  """
  use Phoenix.LiveView
  use Phoenix.HTML

  import PlausibleWeb.Components.Billing

  require Plausible.Billing.Subscription.Status

  alias Plausible.Users
  alias Plausible.Billing.{Plans, Plan, Quota, Subscription}
  alias PlausibleWeb.Router.Helpers, as: Routes

  @contact_link "https://plausible.io/contact"
  @billing_faq_link "https://plausible.io/docs/billing"

  def mount(_params, %{"user_id" => user_id}, socket) do
    socket =
      socket
      |> assign_new(:user, fn ->
        Users.with_subscription(user_id)
      end)
      |> assign_new(:usage, fn %{user: user} ->
        Quota.monthly_pageview_usage(user)
      end)
      |> assign_new(:owned_plan, fn %{user: %{subscription: subscription}} ->
        Plans.get_regular_plan(subscription, only_non_expired: true)
      end)
      |> assign_new(:current_interval, fn %{user: user} ->
        current_user_subscription_interval(user.subscription)
      end)
      |> assign_new(:available_plans, fn %{user: user} ->
        Plans.available_plans_with_prices(user)
      end)
      |> assign_new(:available_volumes, fn %{available_plans: available_plans} ->
        get_available_volumes(available_plans)
      end)
      |> assign_new(:selected_volume, fn %{
                                           owned_plan: owned_plan,
                                           usage: usage,
                                           available_volumes: available_volumes
                                         } ->
        default_selected_volume(owned_plan, usage, available_volumes)
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
    ~H"""
    <div class="bg-gray-100 dark:bg-gray-900 pt-1 pb-12 sm:pb-16 text-gray-900 dark:text-gray-100">
      <div class="mx-auto max-w-7xl px-6 lg:px-8">
        <.subscription_past_due_notice class="pb-2" subscription={@user.subscription} />
        <.subscription_paused_notice class="pb-2" subscription={@user.subscription} />
        <div class="mx-auto max-w-4xl text-center">
          <p class="text-4xl font-bold tracking-tight sm:text-5xl">
            <%= if @owned_plan,
              do: "Change subscription plan",
              else: "Upgrade your account" %>
          </p>
        </div>
        <.interval_picker selected_interval={@selected_interval} />
        <.slider selected_volume={@selected_volume} available_volumes={@available_volumes} />
        <div class="mt-6 isolate mx-auto grid max-w-md grid-cols-1 gap-8 lg:mx-0 lg:max-w-none lg:grid-cols-3">
          <.plan_box
            kind={:growth}
            owned={@owned_plan && Map.get(@owned_plan, :kind) == :growth}
            plan_to_render={
              if @selected_growth_plan,
                do: @selected_growth_plan,
                else: List.last(@available_plans.growth)
            }
            available={!!@selected_growth_plan}
            {assigns}
          />
          <.plan_box
            kind={:business}
            owned={@owned_plan && Map.get(@owned_plan, :kind) == :business}
            plan_to_render={
              if @selected_business_plan,
                do: @selected_business_plan,
                else: List.last(@available_plans.business)
            }
            available={!!@selected_business_plan}
            {assigns}
          />
          <.enterprise_plan_box />
        </div>
        <p class="mx-auto mt-2 max-w-2xl text-center text-lg leading-8 text-gray-600 dark:text-gray-400">
          <.usage usage={@usage} />
        </p>
        <.pageview_limit_notice :if={!@owned_plan} />
        <.help_links />
      </div>
    </div>
    <.slider_styles />
    <.paddle_script />
    """
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

  defp default_selected_volume(%Plan{monthly_pageview_limit: limit}, _, _), do: limit

  defp default_selected_volume(_, usage, available_volumes) do
    Enum.find(available_volumes, &(usage < &1)) || :enterprise
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
    <div class="mt-6 flex justify-center">
      <div class="flex flex-col">
        <.two_months_free active={@selected_interval == :yearly} />
        <fieldset class="grid grid-cols-2 gap-x-1 rounded-full p-1 text-center text-xs font-semibold leading-5 ring-1 ring-inset ring-gray-300 dark:ring-gray-600">
          <label
            class={"cursor-pointer rounded-full px-2.5 py-1 #{if @selected_interval == :monthly, do: "bg-indigo-600 text-white"}"}
            phx-click="set_interval"
            phx-value-interval="monthly"
          >
            <input type="radio" name="frequency" value="monthly" class="sr-only" />
            <span>Monthly</span>
          </label>
          <label
            class={"cursor-pointer rounded-full px-2.5 py-1 #{if @selected_interval == :yearly, do: "bg-indigo-600 text-white"}"}
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
    <div class="grid grid-cols-2 gap-x-1">
      <div></div>
      <span
        id="two-months-free"
        class={[
          "mb-1 block whitespace-no-wrap w-max px-2.5 py-0.5 rounded-full text-xs font-medium leading-4 ring-1",
          @active &&
            "bg-yellow-100 ring-yellow-700 text-yellow-700 dark:text-yellow-200 dark:bg-inherit dark:ring-1 dark:ring-yellow-200",
          !@active && "text-gray-500 ring-gray-300 dark:text-gray-400 dark:ring-gray-600"
        ]}
      >
        2 months free
      </span>
    </div>
    """
  end

  defp slider(assigns) do
    ~H"""
    <form class="mt-4 max-w-2xl mx-auto">
      <p class="text-xl text-gray-600 dark:text-gray-400 text-center">
        Monthly pageviews: <b><%= slider_value(@selected_volume, @available_volumes) %></b>
      </p>
      <input
        phx-change="slide"
        name="slider"
        class="shadow-md border border-gray-200 dark:bg-gray-600 dark:border-none"
        type="range"
        min="0"
        max={length(@available_volumes)}
        step="1"
        value={
          Enum.find_index(@available_volumes, &(&1 == @selected_volume)) || length(@available_volumes)
        }
      />
    </form>
    """
  end

  defp plan_box(assigns) do
    ~H"""
    <div
      id={"#{@kind}-plan-box"}
      class={[
        "rounded-3xl px-6 sm:px-8 py-4 sm:py-6 dark:bg-gray-800",
        !@owned && "ring-1 ring-gray-300 dark:ring-gray-600",
        @owned && "ring-2 ring-indigo-600"
      ]}
    >
      <div class="flex items-center justify-between gap-x-4">
        <h3 class={[
          "text-lg font-semibold leading-8",
          !@owned && "text-gray-900 dark:text-gray-100",
          @owned && "text-indigo-600"
        ]}>
          <%= String.capitalize(to_string(@kind)) %>
        </h3>
        <.current_label :if={@owned} />
      </div>
      <div>
        <.render_price_info available={@available} {assigns} />
        <%= cond do %>
          <% !@available -> %>
            <.contact_button class="bg-indigo-600 hover:bg-indigo-500 text-white" />
          <% @owned_plan && Plausible.Billing.Subscriptions.resumable?(@user.subscription) -> %>
            <.render_change_plan_link
              paddle_product_id={get_paddle_product_id(@plan_to_render, @selected_interval)}
              text={
                change_plan_link_text(
                  @owned_plan,
                  @plan_to_render,
                  @current_interval,
                  @selected_interval
                )
              }
              {assigns}
            />
          <% true -> %>
            <.paddle_button
              id={"#{@kind}-checkout"}
              paddle_product_id={get_paddle_product_id(@plan_to_render, @selected_interval)}
              {assigns}
            >
              Upgrade
            </.paddle_button>
        <% end %>
      </div>
      <ul
        role="list"
        class="mt-8 space-y-3 text-sm leading-6 text-gray-600 dark:text-gray-100 xl:mt-10"
      >
        <li class="flex gap-x-3">
          <.check_icon class="text-indigo-600 dark:text-green-600" /> 5 products
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-indigo-600 dark:text-green-600" /> Up to 1,000 subscribers
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-indigo-600 dark:text-green-600" /> Basic analytics
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-indigo-600 dark:text-green-600" /> 48-hour support response time
        </li>
      </ul>
    </div>
    """
  end

  def render_price_info(%{available: false} = assigns) do
    ~H"""
    <p class="mt-6 flex items-baseline gap-x-1">
      <span class="text-4xl font-bold tracking-tight text-gray-900 dark:text-white">
        Custom
      </span>
    </p>
    <p class="h-4 mt-1"></p>
    """
  end

  def render_price_info(assigns) do
    ~H"""
    <p class="mt-6 flex items-baseline gap-x-1">
      <.price_tag
        kind={@kind}
        selected_interval={@selected_interval}
        plan_to_render={@plan_to_render}
      />
    </p>
    <p class="mt-1 text-xs">+ VAT if applicable</p>
    """
  end

  defp render_change_plan_link(assigns) do
    ~H"""
    <.change_plan_link
      plan_already_owned={@text == "Currently on this plan"}
      billing_details_expired={
        @user.subscription &&
          @user.subscription.status in [Subscription.Status.past_due(), Subscription.Status.paused()]
      }
      {assigns}
    />
    """
  end

  defp change_plan_link(assigns) do
    ~H"""
    <.link
      id={"#{@kind}-checkout"}
      href={Routes.billing_path(PlausibleWeb.Endpoint, :change_plan_preview, @paddle_product_id)}
      class={[
        "w-full mt-6 block rounded-md py-2 px-3 text-center text-sm font-semibold leading-6 text-white",
        !(@plan_already_owned || @billing_details_expired) && "bg-indigo-600 hover:bg-indigo-500",
        (@plan_already_owned || @billing_details_expired) &&
          "pointer-events-none bg-gray-400 dark:bg-gray-600"
      ]}
    >
      <%= @text %>
    </.link>
    <p
      :if={@billing_details_expired && !@plan_already_owned}
      class="text-center text-sm text-red-700 dark:text-red-500"
    >
      Please update your billing details first
    </p>
    """
  end

  defp contact_button(assigns) do
    ~H"""
    <.link
      href={contact_link()}
      class={[
        "mt-6 block rounded-md py-2 px-3 text-center text-sm font-semibold leading-6 bg-gray-800 hover:bg-gray-700 text-white dark:bg-indigo-600 dark:hover:bg-indigo-500",
        @class
      ]}
    >
      Contact us
    </.link>
    """
  end

  defp enterprise_plan_box(assigns) do
    ~H"""
    <div class="rounded-3xl px-6 sm:px-8 py-4 sm:py-6 ring-1 bg-gray-900 ring-gray-900 dark:bg-gray-800 dark:ring-gray-600">
      <h3 class="text-lg font-semibold leading-8 text-white dark:text-gray-100">Enterprise</h3>
      <p class="mt-6 flex items-baseline gap-x-1">
        <span class="text-4xl font-bold tracking-tight text-white dark:text-gray-100">
          Custom
        </span>
      </p>
      <p class="h-4 mt-1"></p>
      <.contact_button class="" />
      <ul role="list" class="mt-8 space-y-3 text-sm leading-6 xl:mt-10 text-gray-300">
        <li class="flex gap-x-3">
          <.check_icon class="text-white dark:text-green-600" /> Unlimited products
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-white dark:text-green-600" /> Unlimited subscribers
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-white dark:text-green-600" /> Advanced analytics
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-white dark:text-green-600" />
          1-hour, dedicated support response time
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-white dark:text-green-600" /> Marketing automations
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-white dark:text-green-600" /> Custom reporting tools
        </li>
      </ul>
    </div>
    """
  end

  defp current_label(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-x-4">
      <p
        id="current-label"
        class="rounded-full bg-indigo-600/10 px-2.5 py-1 text-xs font-semibold leading-5 text-indigo-600 dark:ring-1 dark:ring-indigo-600/40"
      >
        Current
      </p>
    </div>
    """
  end

  defp check_icon(assigns) do
    ~H"""
    <svg {%{class: "h-6 w-5 flex-none #{@class}", viewBox: "0 0 20 20",fill: "currentColor","aria-hidden": "true"}}>
      <path
        fill-rule="evenodd"
        d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp usage(assigns) do
    ~H"""
    You have used <b><%= PlausibleWeb.AuthView.delimit_integer(@usage) %></b>
    billable pageviews in the last 30 days
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

  defp price_tag(%{plan_to_render: %Plan{monthly_cost: nil}} = assigns) do
    ~H"""
    <span class="text-4xl font-bold tracking-tight text-gray-900">
      N/A
    </span>
    """
  end

  defp price_tag(%{selected_interval: :monthly} = assigns) do
    ~H"""
    <span
      id={"#{@kind}-price-tag-amount"}
      class="text-4xl font-bold tracking-tight text-gray-900 dark:text-gray-100"
    >
      <%= @plan_to_render.monthly_cost |> format_price() %>
    </span>
    <span
      id={"#{@kind}-price-tag-interval"}
      class="text-sm font-semibold leading-6 text-gray-600 dark:text-gray-500"
    >
      /month
    </span>
    """
  end

  defp price_tag(%{selected_interval: :yearly} = assigns) do
    ~H"""
    <span class="text-2xl font-bold w-max tracking-tight line-through text-gray-500 dark:text-gray-600 mr-1">
      <%= @plan_to_render.monthly_cost |> Money.mult!(12) |> format_price() %>
    </span>
    <span
      id={"#{@kind}-price-tag-amount"}
      class="text-4xl font-bold tracking-tight text-gray-900 dark:text-gray-100"
    >
      <%= @plan_to_render.yearly_cost |> format_price() %>
    </span>
    <span id={"#{@kind}-price-tag-interval"} class="text-sm font-semibold leading-6 text-gray-600">
      /year
    </span>
    """
  end

  defp slider_styles(assigns) do
    ~H"""
    <style>
      input[type="range"] {
        -moz-appearance: none;
        -webkit-appearance: none;
        background: white;
        border-radius: 3px;
        height: 6px;
        width: 100%;
        margin-top: 25px;
        margin-bottom: 15px;
        outline: none;
      }

      input[type="range"]::-webkit-slider-thumb {
        appearance: none;
        -webkit-appearance: none;
        background-color: #5f48ff;
        background-image: url("data:image/svg+xml;charset=US-ASCII,%3Csvg%20width%3D%2212%22%20height%3D%228%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M8%20.5v7L12%204zM0%204l4%203.5v-7z%22%20fill%3D%22%23FFFFFF%22%20fill-rule%3D%22nonzero%22%2F%3E%3C%2Fsvg%3E");
        background-position: center;
        background-repeat: no-repeat;
        border: 0;
        border-radius: 50%;
        cursor: pointer;
        height: 36px;
        width: 36px;
      }

      input[type="range"]::-moz-range-thumb {
        background-color: #5f48ff;
        background-image: url("data:image/svg+xml;charset=US-ASCII,%3Csvg%20width%3D%2212%22%20height%3D%228%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M8%20.5v7L12%204zM0%204l4%203.5v-7z%22%20fill%3D%22%23FFFFFF%22%20fill-rule%3D%22nonzero%22%2F%3E%3C%2Fsvg%3E");
        background-position: center;
        background-repeat: no-repeat;
        border: 0;
        border: none;
        border-radius: 50%;
        cursor: pointer;
        height: 36px;
        width: 36px;
      }

      input[type="range"]::-ms-thumb {
        background-color: #5f48ff;
        background-image: url("data:image/svg+xml;charset=US-ASCII,%3Csvg%20width%3D%2212%22%20height%3D%228%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M8%20.5v7L12%204zM0%204l4%203.5v-7z%22%20fill%3D%22%23FFFFFF%22%20fill-rule%3D%22nonzero%22%2F%3E%3C%2Fsvg%3E");
        background-position: center;
        background-repeat: no-repeat;
        border: 0;
        border-radius: 50%;
        cursor: pointer;
        height: 36px;
        width: 36px;
      }

      input[type="range"]::-moz-focus-outer {
        border: 0;
      }
    </style>
    """
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp change_plan_link_text(
         %Plan{kind: from_kind, monthly_pageview_limit: from_volume},
         %Plan{kind: to_kind, monthly_pageview_limit: to_volume},
         from_interval,
         to_interval
       ) do
    cond do
      from_kind == :business && to_kind == :growth ->
        "Downgrade to Growth"

      from_kind == :growth && to_kind == :business ->
        "Upgrade to Business"

      from_volume == to_volume && from_interval == to_interval ->
        "Currently on this plan"

      from_volume == to_volume ->
        "Change billing interval"

      from_volume > to_volume ->
        "Downgrade"

      true ->
        "Upgrade"
    end
  end

  defp get_available_volumes(%{business: business_plans, growth: growth_plans}) do
    growth_volumes = Enum.map(growth_plans, & &1.monthly_pageview_limit)
    business_volumes = Enum.map(business_plans, & &1.monthly_pageview_limit)

    (growth_volumes ++ business_volumes)
    |> Enum.uniq()
  end

  defp get_paddle_product_id(%Plan{monthly_product_id: plan_id}, :monthly), do: plan_id
  defp get_paddle_product_id(%Plan{yearly_product_id: plan_id}, :yearly), do: plan_id

  defp slider_value(:enterprise, available_volumes) do
    List.last(available_volumes)
    |> PlausibleWeb.StatsView.large_number_format()
    |> Kernel.<>("+")
  end

  defp slider_value(volume, _) when is_integer(volume) do
    PlausibleWeb.StatsView.large_number_format(volume)
  end

  defp contact_link(), do: @contact_link

  defp billing_faq_link(), do: @billing_faq_link
end
