defmodule PlausibleWeb.Live.Shields.CountryRules do
  @moduledoc """
  LiveView allowing Country Rules management
  """

  use Phoenix.LiveComponent, global_prefixes: ~w(x-)
  use Phoenix.HTML

  alias PlausibleWeb.Live.Components.Modal
  alias Plausible.Shields
  alias Plausible.Shield

  def update(assigns, socket) do
    socket =
      socket
      |> assign(
        country_rules_count: assigns.country_rules_count,
        site: assigns.site,
        current_user: assigns.current_user,
        form: new_form()
      )
      |> assign_new(:country_rules, fn %{site: site} ->
        Shields.list_country_rules(site)
      end)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <section class="shadow bg-white dark:bg-gray-800 sm:rounded-md sm:overflow-hidden">
      <div class="py-6 px-4 sm:p-6">
        <header class="relative">
          <h2 class="text-lg leading-6 font-medium text-gray-900 dark:text-gray-100">
            Country Block List
          </h2>
          <p class="mt-1 mb-4 text-sm leading-5 text-gray-500 dark:text-gray-200">
            Reject incoming traffic from specific countries
          </p>

          <PlausibleWeb.Components.Generic.docs_info slug="countries" />
        </header>
        <div class="border-t border-gray-200 pt-4 grid">
          <div
            :if={@country_rules_count < Shields.maximum_country_rules()}
            class="mt-4 sm:ml-4 sm:mt-0 justify-self-end"
          >
            <PlausibleWeb.Components.Generic.button
              id="add-country-rule"
              x-data
              x-on:click={Modal.JS.open("country-rule-form-modal")}
            >
              + Add Country
            </PlausibleWeb.Components.Generic.button>
          </div>
          <PlausibleWeb.Components.Generic.notice
            :if={@country_rules_count >= Shields.maximum_country_rules()}
            class="mt-4"
            title="Maximum number of countries reached"
          >
            <p>
              You've reached the maximum number of countries you can block (<%= Shields.maximum_country_rules() %>). Please remove one before adding another.
            </p>
          </PlausibleWeb.Components.Generic.notice>
        </div>

        <.live_component module={Modal} id="country-rule-form-modal">
          <.form
            :let={f}
            for={@form}
            phx-submit="save-country-rule"
            phx-target={@myself}
            class="max-w-md w-full mx-auto bg-white dark:bg-gray-800"
          >
            <h2 class="text-xl font-black dark:text-gray-100 mb-8">Add Country to Block List</h2>

            <.live_component
              submit_name="country_rule[country_code]"
              submit_value={f[:country_code].value}
              display_value=""
              module={PlausibleWeb.Live.Components.ComboBox}
              suggest_fun={&PlausibleWeb.Live.Components.ComboBox.StaticSearch.suggest/2}
              id={f[:country_code].id}
              suggestions_limit={300}
              options={options(@country_rules)}
            />

            <p class="text-sm mt-2 text-gray-500 dark:text-gray-200">
              Once added, we will start rejecting traffic from this country within a few minutes.
            </p>
            <div class="py-4 mt-8">
              <PlausibleWeb.Components.Generic.button type="submit" class="w-full">
                Add Country →
              </PlausibleWeb.Components.Generic.button>
            </div>
          </.form>
        </.live_component>

        <p
          :if={Enum.empty?(@country_rules)}
          class="text-sm text-gray-800 dark:text-gray-200 mt-12 mb-8 text-center"
        >
          No Country Rules configured for this Site.
        </p>
        <div
          :if={not Enum.empty?(@country_rules)}
          class="mt-8 overflow-hidden border-b border-gray-200 shadow dark:border-gray-900 sm:rounded-lg"
        >
          <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-900">
            <thead class="bg-gray-50 dark:bg-gray-900">
              <tr>
                <th
                  scope="col"
                  class="px-6 py-3 text-xs font-medium text-left text-gray-500 uppercase dark:text-gray-100"
                >
                  Country
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
              <%= for rule <- @country_rules do %>
                <% country = Location.Country.get_country(rule.country_code) %>
                <tr class="text-gray-900 dark:text-gray-100">
                  <td class="px-6 py-4 text-sm font-medium">
                    <div class="flex items-center">
                      <span
                        id={"country-#{rule.id}"}
                        class="mr-4 cursor-help border-b border-dotted border-gray-400"
                        title={"Added at #{format_added_at(rule.inserted_at, @site.timezone)} by #{rule.added_by}"}
                      >
                        <%= country.flag %> <%= country.name %>
                      </span>
                    </div>
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-500">
                    <span :if={rule.action == :deny}>
                      Blocked
                    </span>
                    <span :if={rule.action == :allow}>
                      Allowed
                    </span>
                  </td>
                  <td class="px-6 py-4 text-sm font-medium text-right">
                    <button
                      id={"remove-country-rule-#{rule.id}"}
                      phx-target={@myself}
                      phx-click="remove-country-rule"
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

  def handle_event("save-country-rule", %{"country_rule" => params}, socket) do
    user = socket.assigns.current_user

    case Shields.add_country_rule(
           socket.assigns.site.id,
           params,
           added_by: user
         ) do
      {:ok, rule} ->
        country_rules = [rule | socket.assigns.country_rules]

        socket =
          socket
          |> Modal.close("country-rule-form-modal")
          |> assign(
            form: new_form(),
            country_rules: country_rules,
            country_rules_count: socket.assigns.country_rules_count + 1
          )

        # Make sure to clear the combobox input after adding a country rule, on subsequent modal reopening
        send_update(PlausibleWeb.Live.Components.ComboBox,
          id: "country_rule_country_code",
          display_value: ""
        )

        send_flash(
          :success,
          "Country rule added successfully. Traffic will be rejected within a few minutes."
        )

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("remove-country-rule", %{"rule-id" => rule_id}, socket) do
    Shields.remove_country_rule(socket.assigns.site.id, rule_id)

    send_flash(
      :success,
      "Country rule removed successfully. Traffic will be resumed within a few minutes."
    )

    {:noreply,
     socket
     |> assign(
       country_rules_count: socket.assigns.country_rules_count - 1,
       country_rules: Enum.reject(socket.assigns.country_rules, &(&1.id == rule_id))
     )}
  end

  def send_flash(kind, message) do
    send(self(), {:flash, kind, message})
  end

  defp new_form() do
    %Shield.CountryRule{}
    |> Shield.CountryRule.changeset(%{})
    |> to_form()
  end

  defp options(country_rules) do
    Location.Country.all()
    |> Enum.sort_by(& &1.name)
    |> Enum.map(fn c -> {c.alpha_2, c.flag <> " " <> c.name} end)
    |> Enum.reject(fn {country_code, _} ->
      country_code in Enum.map(country_rules, & &1.country_code)
    end)
  end

  defp format_added_at(dt, tz) do
    dt
    |> Plausible.Timezones.to_datetime_in_timezone(tz)
    |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:{m}:{s}")
  end
end
