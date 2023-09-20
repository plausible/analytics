defmodule PlausibleWeb.Live.ChoosePlan do
  use Phoenix.LiveView
  use Phoenix.HTML
  alias Plausible.{Billing, Users}
  alias Plausible.Billing.{Plans, Plan}

  import PlausibleWeb.Components.Billing

  @volumes [10_000, 100_000, 200_000, 500_000, 1_000_000, 2_000_000, 5_000_000, 10_000_000]
  @contact_link "https://plausible.io/contact"
  @billing_faq_link "https://plausible.io/docs/billing"

  def mount(_params, %{"user_id" => user_id}, socket) do
    user = Users.with_subscription(user_id)

    usage =
      user
      |> Billing.usage_breakdown()
      |> then(fn {pageviews, custom_events} -> pageviews + custom_events end)

    current_user_plan = Plans.get_subscription_plan(user.subscription)
    current_interval = current_user_subscription_interval(user.subscription)
    selected_volume = default_selected_volume(current_user_plan)

    available_plans = Plans.available_plans_with_prices(user)

    {:ok,
     assign(
       socket,
       user: user,
       usage: usage,
       current_user_plan: current_user_plan,
       current_interval: current_interval,
       selected_interval: current_interval || :monthly,
       selected_volume: selected_volume,
       available_plans: available_plans,
       selected_growth_plan: get_plan_by_volume(available_plans.growth, selected_volume),
       selected_business_plan: get_plan_by_volume(available_plans.business, selected_volume)
     )}
  end

  def render(assigns) do
    ~H"""
    <.subscription_past_due_notice class="container mb-2 mt-4" subscription={@user.subscription} />
    <.subscription_paused_notice class="container mb-2 mt-4" subscription={@user.subscription} />
    <div class="bg-gray-100 py-12 sm:py-16">
      <div class="mx-auto max-w-7xl px-6 lg:px-8">
        <div class="mx-auto max-w-4xl text-center">
          <p class="mt-2 text-4xl font-bold tracking-tight text-gray-900 sm:text-5xl">
            <%= if @current_user_plan,
              do: "Change subscription plan",
              else: "Upgrade your free trial" %>
          </p>
        </div>
        <p class="mx-auto mt-6 max-w-2xl text-center text-lg leading-8 text-gray-600">
          <.usage usage={@usage} />
        </p>
        <.interval_picker selected_interval={@selected_interval} />
        <.slider selected_volume={@selected_volume} />
        <div class="isolate mx-auto mt-10 grid max-w-md grid-cols-1 gap-8 lg:mx-0 lg:max-w-none lg:grid-cols-3">
          <.plan_box
            name="Growth"
            owned={@current_user_plan && Map.get(@current_user_plan, :kind) == :growth}
            selected_plan={@selected_growth_plan}
            {assigns}
          />
          <.plan_box
            name="Business"
            owned={@current_user_plan && Map.get(@current_user_plan, :kind) == :business}
            selected_plan={@selected_business_plan}
            {assigns}
          />
          <.enterprise_plan_box />
        </div>
        <.pageview_limit_notice :if={!@current_user_plan} />
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
    new_volume = Enum.at(@volumes, String.to_integer(index))

    {:noreply,
     assign(socket,
       selected_volume: new_volume,
       selected_growth_plan:
         get_plan_by_volume(socket.assigns.available_plans.growth, new_volume),
       selected_business_plan:
         get_plan_by_volume(socket.assigns.available_plans.business, new_volume)
     )}
  end

  defp default_selected_volume(%Plan{monthly_pageview_limit: limit}), do: limit
  defp default_selected_volume(_), do: List.first(@volumes)

  defp current_user_subscription_interval(subscription) do
    case Plans.subscription_interval(subscription) do
      "yearly" -> :yearly
      "monthly" -> :monthly
      _ -> nil
    end
  end

  defp get_plan_by_volume(plans, volume) do
    Enum.find(plans, &(&1.monthly_pageview_limit == volume))
  end

  defp interval_picker(assigns) do
    ~H"""
    <div class="mt-16 flex justify-center">
      <fieldset class="grid grid-cols-2 gap-x-1 rounded-full p-1 text-center text-xs font-semibold leading-5 ring-1 ring-inset ring-gray-300">
        <label
          class={"cursor-pointer rounded-full px-2.5 py-1 #{if @selected_interval === :monthly, do: "bg-indigo-600 text-white"}"}
          phx-click="set_interval"
          phx-value-interval="monthly"
        >
          <input type="radio" name="frequency" value="monthly" class="sr-only" />
          <span>Monthly billing</span>
        </label>
        <label
          class={"cursor-pointer rounded-full px-2.5 py-1 #{if @selected_interval === :yearly, do: "bg-indigo-600 text-white"}"}
          phx-click="set_interval"
          phx-value-interval="yearly"
        >
          <input type="radio" name="frequency" value="yearly" class="sr-only" />
          <span>Yearly billing</span>
        </label>
      </fieldset>
    </div>
    """
  end

  defp slider(assigns) do
    ~H"""
    <form class="mt-6 max-w-2xl mx-auto">
      <p class="text-xl text-gray-600 text-center">
        Monthly pageviews: <b><%= PlausibleWeb.StatsView.large_number_format(@selected_volume) %></b>
      </p>
      <input
        phx-change="slide"
        name="slider"
        class="shadow-lg"
        type="range"
        min="0"
        max="7"
        step="1"
        value={Enum.find_index(volumes(), &(&1 == @selected_volume))}
      />
    </form>
    """
  end

  defp plan_box(assigns) do
    ~H"""
    <div
      id={"plan-box-#{String.downcase(@name)}"}
      class={[
        "relative rounded-3xl p-8 xl:p-10 ring-gray-300 ring-1",
        @owned && "ring-2 ring-indigo-600"
      ]}
    >
      <.current_label :if={@owned} />
      <div class="flex items-center justify-between gap-x-4">
        <h3 class="text-lg font-semibold leading-8 text-gray-900">
          <%= @name %>
        </h3>
      </div>
      <p class="mt-6 flex items-baseline gap-x-1">
        <.price_tag selected_interval={@selected_interval} selected_plan={@selected_plan} />
      </p>
      <%= if @user.subscription && @user.subscription.status in ["active", "past_due", "paused"] do %>
        <.render_change_plan_link
          selected_plan_id={get_selected_plan_id(@selected_plan, @selected_interval)}
          text={
            change_plan_link_text(
              @current_user_plan,
              @selected_plan,
              @current_interval,
              @selected_interval
            )
          }
          {assigns}
        />
      <% else %>
        <.paddle_button
          selected_plan_id={get_selected_plan_id(@selected_plan, @selected_interval)}
          user={@user}
        />
      <% end %>
      <ul role="list" class="mt-8 space-y-3 text-sm leading-6 text-gray-600 xl:mt-10">
        <li class="flex gap-x-3">
          <.check_icon class="text-indigo-600" /> 5 products
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-indigo-600" /> Up to 1,000 subscribers
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-indigo-600" /> Basic analytics
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-indigo-600" /> 48-hour support response time
        </li>
      </ul>
    </div>
    """
  end

  defp render_change_plan_link(assigns) do
    ~H"""
    <.change_plan_link
      plan_already_owned={@text == "Currently on this plan"}
      billing_details_expired={
        @user.subscription && @user.subscription.status in ["past_due", "paused"]
      }
      {assigns}
    />
    """
  end

  defp change_plan_link(assigns) do
    ~H"""
    <.link
      id="checkout"
      href={"/billing/change-plan/preview/" <> @selected_plan_id}
      class={[
        "w-full mt-6 block rounded-md py-2 px-3 text-center text-sm font-semibold leading-6 text-white",
        !(@plan_already_owned || @billing_details_expired) && "bg-indigo-600 hover:bg-indigo-500",
        (@plan_already_owned || @billing_details_expired) && "pointer-events-none bg-gray-400"
      ]}
    >
      <%= @text %>
    </.link>
    <p :if={@billing_details_expired && !@plan_already_owned} class="text-center text-sm text-red-500">
      Please update your billing details first
    </p>
    """
  end

  defp paddle_button(assigns) do
    ~H"""
    <button
      id="checkout"
      data-theme="none"
      data-product={@selected_plan_id}
      data-email={@user.email}
      data-disable-logout="true"
      data-passthrough={@user.id}
      data-success="/billing/upgrade-success"
      data-init="true"
      class="paddle_button w-full mt-6 block rounded-md py-2 px-3 text-center text-sm font-semibold leading-6 text-white bg-indigo-600 hover:bg-indigo-500"
    >
      Upgrade
    </button>
    """
  end

  defp enterprise_plan_box(assigns) do
    ~H"""
    <div class="rounded-3xl p-8 ring-1 xl:p-10 bg-gray-900 ring-gray-900">
      <h3 class="text-lg font-semibold leading-8 text-white">Enterprise</h3>
      <p class="mt-6 flex items-baseline gap-x-1">
        <span class="text-4xl font-bold tracking-tight text-white">Custom</span>
      </p>
      <a {%{href: contact_link(), class: "mt-6 block rounded-md py-2 px-3 text-center text-sm font-semibold leading-6 bg-gray-800 hover:bg-gray-700 text-white"}}>
        Contact us
      </a>
      <ul role="list" class="mt-8 space-y-3 text-sm leading-6 xl:mt-10 text-gray-300">
        <li class="flex gap-x-3">
          <.check_icon class="text-white" /> Unlimited products
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-white" /> Unlimited subscribers
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-white" /> Advanced analytics
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-white" /> 1-hour, dedicated support response time
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-white" /> Marketing automations
        </li>
        <li class="flex gap-x-3">
          <.check_icon class="text-white" /> Custom reporting tools
        </li>
      </ul>
    </div>
    """
  end

  defp current_label(assigns) do
    ~H"""
    <div class="text-sm font-semibold text-white bg-green-300 absolute -right-1 -top-1 w-max px-4 py-1 rounded-md rounded-md ring-2 ring-indigo-600 text-center bg-indigo-600">
      CURRENT
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
        <p class="w-full text-center text-gray-900">
          <span class="text-center font-semibold leading-7">
            What happens if I go over my page views limit?
          </span>
        </p>
      </dt>
      <dd class="mt-3">
        <div class="text-justify leading-7 block text-gray-600">
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

  defp price_tag(%{selected_plan: %Plan{monthly_cost: nil, yearly_cost: nil}} = assigns) do
    ~H"""
    <span class="text-4xl font-bold tracking-tight text-gray-900">
      N/A
    </span>
    <span class="text-sm font-semibold leading-6 text-gray-600">
      ❗️
    </span>
    """
  end

  defp price_tag(%{selected_interval: :monthly} = assigns) do
    ~H"""
    <span class="text-4xl font-bold tracking-tight text-gray-900">
      <%= @selected_plan.monthly_cost
      |> Money.to_string!(format: :short, fractional_digits: 2)
      |> String.replace(".00", "") %>
    </span>
    <span class="text-sm font-semibold leading-6 text-gray-600">
      /month
    </span>
    """
  end

  defp price_tag(%{selected_interval: :yearly} = assigns) do
    ~H"""
    <span class="text-4xl font-bold tracking-tight text-gray-900">
      <%= @selected_plan.yearly_cost
      |> Money.to_string!(format: :short, fractional_digits: 2)
      |> String.replace(".00", "") %>
    </span>
    <span class="text-sm font-semibold leading-6 text-gray-600">
      /year
    </span>
    """
  end

  defp paddle_script(assigns) do
    ~H"""
    <script type="text/javascript" src="https://cdn.paddle.com/paddle/paddle.js">
    </script>
    <script :if={Application.get_env(:plausible, :environment) == "dev"}>
      Paddle.Environment.set('sandbox')
    </script>
    <script>
      Paddle.Setup({vendor: <%= Application.get_env(:plausible, :paddle) |> Keyword.fetch!(:vendor_id) %> })
    </script>
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

  defp get_selected_plan_id(%Plan{monthly_product_id: plan_id}, :monthly), do: plan_id
  defp get_selected_plan_id(%Plan{yearly_product_id: plan_id}, :yearly), do: plan_id

  defp volumes(), do: @volumes

  defp contact_link(), do: @contact_link

  defp billing_faq_link(), do: @billing_faq_link
end
