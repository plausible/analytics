defmodule PlausibleWeb.Live.Shields.PageRules do
  @moduledoc """
  LiveView allowing page Rules management
  """

  use Phoenix.LiveComponent, global_prefixes: ~w(x-)
  use Phoenix.HTML

  alias PlausibleWeb.Live.Components.Modal
  alias Plausible.Shields
  alias Plausible.Shield

  import PlausibleWeb.ErrorHelpers

  def update(assigns, socket) do
    socket =
      socket
      |> assign(
        page_rules_count: assigns[:page_rules_count] || socket.assigns.page_rules_count,
        site: assigns[:site] || socket.assigns.site,
        current_user: assigns[:current_user] || socket.assigns.current_user,
        form: new_form()
      )
      |> assign_new(:page_rules, fn %{site: site} ->
        Shields.list_page_rules(site)
      end)
      |> assign_new(:redundant_rules, fn %{page_rules: page_rules} ->
        detect_redundancy(page_rules)
      end)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <section class="shadow bg-white dark:bg-gray-800 sm:rounded-md sm:overflow-hidden">
      <div class="py-6 px-4 sm:p-6">
        <header class="relative">
          <h2 class="text-lg leading-6 font-medium text-gray-900 dark:text-gray-100">
            Pages Block List
          </h2>
          <p class="mt-1 mb-4 text-sm leading-5 text-gray-500 dark:text-gray-200">
            Reject incoming traffic for specific pages
          </p>

          <PlausibleWeb.Components.Generic.docs_info slug="top-pages#block-traffic-from-specific-pages-or-sections" />
        </header>
        <div class="border-t border-gray-200 pt-4 grid">
          <div
            :if={@page_rules_count < Shields.maximum_page_rules()}
            class="mt-4 sm:ml-4 sm:mt-0 justify-self-end"
          >
            <PlausibleWeb.Components.Generic.button
              id="add-page-rule"
              x-data
              x-on:click={Modal.JS.open("page-rule-form-modal")}
            >
              + Add Page
            </PlausibleWeb.Components.Generic.button>
          </div>
          <PlausibleWeb.Components.Generic.notice
            :if={@page_rules_count >= Shields.maximum_page_rules()}
            class="mt-4"
            title="Maximum number of pages reached"
          >
            <p>
              You've reached the maximum number of pages you can block (<%= Shields.maximum_page_rules() %>). Please remove one before adding another.
            </p>
          </PlausibleWeb.Components.Generic.notice>
        </div>

        <.live_component :let={modal_unique_id} module={Modal} id="page-rule-form-modal">
          <.form
            :let={f}
            for={@form}
            phx-submit="save-page-rule"
            phx-target={@myself}
            class="max-w-md w-full mx-auto bg-white dark:bg-gray-800"
          >
            <h2 class="text-xl font-black dark:text-gray-100 mb-8">Add Page to Block List</h2>

            <.live_component
              submit_name="page_rule[page_path]"
              submit_value={f[:page_path].value}
              display_value={f[:page_path].value || ""}
              module={PlausibleWeb.Live.Components.ComboBox}
              suggest_fun={fn input, options -> suggest_page_paths(input, options, @site) end}
              id={"#{f[:page_path].id}-#{modal_unique_id}"}
              creatable
            />

            <%= error_tag(f, :page_path) %>

            <p class="text-sm mt-2 text-gray-500 dark:text-gray-200">
              You can use a wildcard (<code>*</code>) to match multiple pages. For example,
              <code>/blog/*</code>
              will match <code>/blog/post</code>.
              Once added, we will start rejecting traffic from this page within a few minutes.
            </p>
            <div class="py-4 mt-8">
              <PlausibleWeb.Components.Generic.button type="submit" class="w-full">
                Add Page →
              </PlausibleWeb.Components.Generic.button>
            </div>
          </.form>
        </.live_component>

        <p
          :if={Enum.empty?(@page_rules)}
          class="text-sm text-gray-800 dark:text-gray-200 mt-12 mb-8 text-center"
        >
          No Page Rules configured for this Site.
        </p>
        <div
          :if={not Enum.empty?(@page_rules)}
          class="mt-8 overflow-visible border-b border-gray-200 shadow dark:border-gray-900 sm:rounded-lg"
        >
          <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-900">
            <thead class="bg-gray-50 dark:bg-gray-900">
              <tr>
                <th
                  scope="col"
                  class="px-6 py-3 text-xs font-medium text-left text-gray-500 uppercase dark:text-gray-100"
                >
                  page
                </th>
                <th
                  scope="col"
                  class="px-6 py-3 text-xs font-medium text-left text-gray-500 uppercase dark:text-gray-100"
                >
                  Status
                </th>
                <th scope="col" class="px-6 py-3">
                  <span class="sr-only">Remove</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <%= for rule <- @page_rules do %>
                <tr class="text-gray-900 dark:text-gray-100">
                  <td class="px-6 py-4 text-sm font-medium">
                    <PlausibleWeb.Components.Generic.tooltip>
                      <:tooltip_content>
                        Added at <%= format_added_at(rule.inserted_at, @site.timezone) %> by <%= rule.added_by %>
                      </:tooltip_content>
                      <div
                        id={"page-#{rule.id}"}
                        class="mr-4 cursor-help text-ellipsis truncate max-w-xs"
                      >
                        <%= rule.page_path %>
                      </div>
                    </PlausibleWeb.Components.Generic.tooltip>
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-500">
                    <div class="flex items-center">
                      <span :if={rule.action == :deny}>
                        Blocked
                      </span>
                      <span :if={rule.action == :allow}>
                        Allowed
                      </span>

                      <span
                        :if={@redundant_rules[rule.id]}
                        title={"This rule might be redundant because the following rules may match first:\n\n#{Enum.join(@redundant_rules[rule.id], "\n")}"}
                        class="pl-4"
                      >
                        <Heroicons.exclamation_triangle class="h-4 w-4 text-red-500" />
                      </span>
                    </div>
                  </td>

                  <td class="px-6 py-4 text-sm font-medium text-right">
                    <button
                      id={"remove-page-rule-#{rule.id}"}
                      phx-target={@myself}
                      phx-click="remove-page-rule"
                      phx-value-rule-id={rule.id}
                      class="text-sm text-red-600"
                      data-confirm="Are you sure you want to revoke this rule?"
                    >
                      Remove
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </section>
    """
  end

  def handle_event("save-page-rule", %{"page_rule" => params}, socket) do
    user = socket.assigns.current_user

    case Shields.add_page_rule(
           socket.assigns.site.id,
           params,
           added_by: user
         ) do
      {:ok, rule} ->
        page_rules = [rule | socket.assigns.page_rules]

        socket =
          socket
          |> Modal.close("page-rule-form-modal")
          |> assign(
            form: new_form(),
            page_rules: page_rules,
            page_rules_count: socket.assigns.page_rules_count + 1,
            redundant_rules: detect_redundancy(page_rules)
          )

        send_flash(
          :success,
          "Page rule added successfully. Traffic will be rejected within a few minutes."
        )

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("remove-page-rule", %{"rule-id" => rule_id}, socket) do
    Shields.remove_page_rule(socket.assigns.site.id, rule_id)

    send_flash(
      :success,
      "Page rule removed successfully. Traffic will be resumed within a few minutes."
    )

    page_rules = Enum.reject(socket.assigns.page_rules, &(&1.id == rule_id))

    {:noreply,
     socket
     |> assign(
       page_rules_count: socket.assigns.page_rules_count - 1,
       page_rules: page_rules,
       redundant_rules: detect_redundancy(page_rules)
     )}
  end

  def send_flash(kind, message) do
    send(self(), {:flash, kind, message})
  end

  defp new_form() do
    %Shield.PageRule{}
    |> Shield.PageRule.changeset(%{})
    |> to_form()
  end

  defp format_added_at(dt, tz) do
    dt
    |> Plausible.Timezones.to_datetime_in_timezone(tz)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end

  def suggest_page_paths(input, _options, site) do
    query = Plausible.Stats.Query.from(site, %{})

    site
    |> Plausible.Stats.filter_suggestions(query, "page", input)
    |> Enum.map(fn %{label: label, value: value} -> {label, value} end)
  end

  defp detect_redundancy(page_rules) do
    page_rules
    |> Enum.reduce(%{}, fn rule, acc ->
      {[^rule], remaining_rules} =
        Enum.split_with(
          page_rules,
          fn r -> r == rule end
        )

      conflicting =
        remaining_rules
        |> Enum.filter(fn candidate ->
          rule
          |> Map.fetch!(:page_path_pattern)
          |> maybe_compile()
          |> Regex.match?(candidate.page_path)
        end)
        |> Enum.map(& &1.id)

      Enum.reduce(conflicting, acc, fn conflicting_rule_id, acc ->
        Map.update(acc, conflicting_rule_id, [rule.page_path], fn existing ->
          [rule.page_path | existing]
        end)
      end)
    end)
  end

  defp maybe_compile(pattern) when is_binary(pattern), do: Regex.compile!(pattern)
  defp maybe_compile(%Regex{} = pattern), do: pattern
end
