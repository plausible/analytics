defmodule PlausibleWeb.Live.GoalSettings.List do
  @moduledoc """
  Phoenix LiveComponent module that renders a list of goals
  """
  use PlausibleWeb, :live_component
  alias PlausibleWeb.Live.Components.Modal
  alias PlausibleWeb.Components.PrimaDropdown

  attr(:goals, :list, required: true)
  attr(:domain, :string, required: true)
  attr(:filter_text, :string)
  attr(:site, Plausible.Site, required: true)

  def render(assigns) do
    revenue_goals_enabled? = Plausible.Billing.Feature.RevenueGoals.enabled?(assigns.site)

    assigns =
      assigns
      |> assign(:revenue_goals_enabled?, revenue_goals_enabled?)
      |> assign(:searching?, String.trim(assigns.filter_text) != "")

    ~H"""
    <div class="flex flex-col gap-4">
      <%= if @searching? or Enum.count(@goals) > 0 do %>
        <.filter_bar filter_text={@filter_text} placeholder="Search Goals">
          <PrimaDropdown.dropdown id="add-goal-dropdown">
            <PrimaDropdown.dropdown_trigger as={&button/1} mt?={false}>
              Add goal <Heroicons.chevron_down mini class="size-4 mt-0.5" />
            </PrimaDropdown.dropdown_trigger>

            <PrimaDropdown.dropdown_menu>
              <PrimaDropdown.dropdown_item
                phx-click="add-goal"
                phx-value-goal-type="pageviews"
                x-data
                x-on:click={Modal.JS.preopen("goals-form-modal")}
              >
                <Heroicons.plus class={PrimaDropdown.dropdown_item_icon_class()} /> Pageview
              </PrimaDropdown.dropdown_item>
              <PrimaDropdown.dropdown_item
                phx-click="add-goal"
                phx-value-goal-type="custom_events"
                x-data
                x-on:click={Modal.JS.preopen("goals-form-modal")}
              >
                <Heroicons.plus class={PrimaDropdown.dropdown_item_icon_class()} /> Custom event
              </PrimaDropdown.dropdown_item>
              <PrimaDropdown.dropdown_item
                phx-click="add-goal"
                phx-value-goal-type="scroll"
                x-data
                x-on:click={Modal.JS.preopen("goals-form-modal")}
              >
                <Heroicons.plus class={PrimaDropdown.dropdown_item_icon_class()} /> Scroll depth
              </PrimaDropdown.dropdown_item>
            </PrimaDropdown.dropdown_menu>
          </PrimaDropdown.dropdown>
        </.filter_bar>
      <% end %>

      <%= if Enum.count(@goals) > 0 do %>
        <.table rows={@goals}>
          <:thead>
            <.th>Name</.th>
            <.th hide_on_mobile>Type</.th>
          </:thead>
          <:tbody :let={goal}>
            <.td max_width="max-w-52 sm:max-w-64" height="h-16">
              <%= if not @revenue_goals_enabled? && goal.currency do %>
                <div class="truncate">{goal}</div>
                <.tooltip>
                  <:tooltip_content>
                    <p class="text-xs">
                      Revenue Goals act like regular custom<br />
                      events without a Business subscription<br />
                    </p>
                  </:tooltip_content>
                  <span class="w-max flex items-center text-gray-500 italic text-sm">
                    <Heroicons.lock_closed solid class="size-4 mr-1" /> Upgrade Required
                  </span>
                </.tooltip>
              <% else %>
                <div class="font-medium text-sm flex items-center gap-1.5">
                  <span class="truncate">{goal}</span>
                  <.tooltip :if={not Enum.empty?(goal.funnels)} centered?={true}>
                    <:tooltip_content>
                      Belongs to funnel
                    </:tooltip_content>
                    <Heroicons.funnel class="size-3.5 mt-px stroke-2 flex-shrink-0" />
                  </.tooltip>
                  <.tooltip :if={goal.custom_props && map_size(goal.custom_props) > 0} centered?={true}>
                    <:tooltip_content>
                      <div class="text-xs">
                        <div :for={{key, value} <- Enum.to_list(goal.custom_props)}>
                          {key} is {value}
                        </div>
                      </div>
                    </:tooltip_content>
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" class="size-3.5 mt-px flex-shrink-0">
                      <circle fill="currentColor" cx="7.25" cy="7.25" r="1.25"/>
                      <path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 3h5.172a2 2 0 0 1 1.414.586l5.536 5.536a3 3 0 0 1 0 4.243l-2.757 2.757a3 3 0 0 1-4.243 0l-5.536-5.536A2 2 0 0 1 3 9.172V4a1 1 0 0 1 1-1Z"/>
                    </svg>
                  </.tooltip>
                </div>
                <div class="truncate">
                  <.goal_description goal={goal} />
                </div>
              <% end %>
            </.td>
            <.td hide_on_mobile height="h-16">
              <.pill :if={goal.page_path && goal.scroll_threshold > -1} color={:green}>Scroll</.pill>
              <.pill :if={goal.page_path && goal.scroll_threshold == -1} color={:gray}>
                Pageview
              </.pill>
              <.pill :if={goal.event_name && !goal.currency} color={:yellow}>Custom Event</.pill>
              <.pill :if={goal.currency} color={:indigo}>Revenue Goal ({goal.currency})</.pill>
            </.td>
            <.td actions height="h-16">
              <.edit_button
                :if={!goal.currency || (goal.currency && @revenue_goals_enabled?)}
                x-data
                x-on:click={Modal.JS.preopen("goals-form-modal")}
                phx-click="edit-goal"
                phx-value-goal-id={goal.id}
                class="mt-1"
                id={"edit-goal-#{goal.id}"}
              />
              <.edit_button
                :if={goal.currency && !@revenue_goals_enabled?}
                id={"edit-goal-#{goal.id}-disabled"}
                disabled
                class="cursor-not-allowed mt-1"
              />
              <.delete_button
                id={"delete-goal-#{goal.id}"}
                phx-click="delete-goal"
                phx-value-goal-id={goal.id}
                phx-value-goal-name={goal.event_name}
                data-confirm={delete_confirmation_text(goal)}
                class="mt-1"
              />
            </.td>
          </:tbody>
        </.table>
      <% else %>
        <.no_search_results :if={@searching?} />
        <.empty_state :if={not @searching?} />
      <% end %>
    </div>
    """
  end

  defp no_search_results(assigns) do
    ~H"""
    <p class="mt-12 mb-8 text-center text-sm">
      No goals found for this site. Please refine or
      <.styled_link phx-click="reset-filter-text" id="reset-filter-hint">
        reset your search.
      </.styled_link>
    </p>
    """
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center pt-5 pb-6 max-w-md mx-auto">
      <h3 class="text-center text-base font-medium text-gray-900 dark:text-gray-100 leading-7">
        Create your first goal
      </h3>
      <p class="text-center text-sm mt-1 text-gray-500 dark:text-gray-400 leading-5 text-pretty">
        Define actions that you want your users to take, like visiting a certain page, submitting a form, etc.
        <.styled_link href="https://plausible.io/docs/goal-conversions" target="_blank">
          Learn more
        </.styled_link>
      </p>
      <PrimaDropdown.dropdown id="add-goal-dropdown-empty" class="mt-4">
        <PrimaDropdown.dropdown_trigger as={&button/1} mt?={false}>
          Add goal <Heroicons.chevron_down mini class="size-4 mt-0.5" />
        </PrimaDropdown.dropdown_trigger>

        <PrimaDropdown.dropdown_menu>
          <PrimaDropdown.dropdown_item
            phx-click="add-goal"
            phx-value-goal-type="pageviews"
            x-data
            x-on:click={Modal.JS.preopen("goals-form-modal")}
          >
            <Heroicons.plus class={PrimaDropdown.dropdown_item_icon_class()} /> Pageview
          </PrimaDropdown.dropdown_item>
          <PrimaDropdown.dropdown_item
            phx-click="add-goal"
            phx-value-goal-type="custom_events"
            x-data
            x-on:click={Modal.JS.preopen("goals-form-modal")}
          >
            <Heroicons.plus class={PrimaDropdown.dropdown_item_icon_class()} /> Custom event
          </PrimaDropdown.dropdown_item>
          <PrimaDropdown.dropdown_item
            phx-click="add-goal"
            phx-value-goal-type="scroll"
            x-data
            x-on:click={Modal.JS.preopen("goals-form-modal")}
          >
            <Heroicons.plus class={PrimaDropdown.dropdown_item_icon_class()} /> Scroll depth
          </PrimaDropdown.dropdown_item>
        </PrimaDropdown.dropdown_menu>
      </PrimaDropdown.dropdown>
    </div>
    """
  end

  defp page_scroll_description(goal) do
    case pageview_description(goal) do
      "" -> "Scroll > #{goal.scroll_threshold}"
      path -> "Scroll > #{goal.scroll_threshold} on #{path}"
    end
  end

  defp pageview_description(goal) do
    path = goal.page_path

    case goal.display_name do
      "Visit " <> ^path -> ""
      _ -> "#{path}"
    end
  end

  defp custom_event_description(goal) do
    if goal.display_name == goal.event_name, do: "", else: "#{goal.event_name}"
  end

  defp goal_description(assigns) do
    ~H"""
    <span
      :if={@goal.page_path && @goal.scroll_threshold > -1}
      class="block truncate text-gray-400 dark:text-gray-500"
    >
      {page_scroll_description(@goal)}
    </span>

    <span
      :if={@goal.page_path && @goal.scroll_threshold == -1}
      class="block truncate text-gray-400 dark:text-gray-500"
    >
      {pageview_description(@goal)}
    </span>

    <span :if={@goal.event_name} class="block truncate text-gray-400 dark:text-gray-500">
      {custom_event_description(@goal)}
    </span>
    """
  end

  defp delete_confirmation_text(goal) do
    if Enum.empty?(goal.funnels) do
      """
      Are you sure you want to remove the following goal:

      #{goal}

      This will just affect the UI, all of your analytics data will stay intact.
      """
    else
      """
      The goal:

      #{goal}

      is part of some funnel(s). If you are going to delete it, the associated funnels will be either reduced or deleted completely. Are you sure you want to remove the goal?
      """
    end
  end
end
