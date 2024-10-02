defmodule PlausibleWeb.Live.Shields.CountryRules do
  @moduledoc """
  LiveView allowing Country Rules management
  """

  use Phoenix.LiveComponent, global_prefixes: ~w(x-)
  use Phoenix.HTML

  alias PlausibleWeb.Live.Components.Modal
  alias Plausible.Shields
  alias Plausible.Shield
  import PlausibleWeb.Components.Generic

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
    <div>
      <.settings_tiles>
        <.tile docs="excluding">
          <:title>Country Block List</:title>
          <:subtitle>Reject incoming traffic from specific countries</:subtitle>
          <.filter_bar
            :if={@country_rules_count < Shields.maximum_country_rules()}
            filtering_enabled?={false}
          >
            <.button
              id="add-country-rule"
              x-data
              x-on:click={Modal.JS.open("country-rule-form-modal")}
              mt?={false}
            >
              Add Country
            </.button>
          </.filter_bar>

          <.notice
            :if={@country_rules_count >= Shields.maximum_country_rules()}
            class="mt-4"
            title="Maximum number of countries reached"
            theme={:gray}
          >
            <p>
              You've reached the maximum number of countries you can block (<%= Shields.maximum_country_rules() %>). Please remove one before adding another.
            </p>
          </.notice>

          <p :if={Enum.empty?(@country_rules)} class="mt-12 mb-8 text-center text-sm">
            No Country Rules configured for this site.
          </p>

          <.table :if={not Enum.empty?(@country_rules)} rows={@country_rules}>
            <:thead>
              <.th>Country</.th>
              <.th hide_on_mobile>Status</.th>
              <.th invisible>Actions</.th>
            </:thead>
            <:tbody :let={rule}>
              <% country = Location.Country.get_country(rule.country_code) %>
              <.td>
                <div class="flex items-center">
                  <span
                    id={"country-#{rule.id}"}
                    class="mr-4 cursor-help"
                    title={"Added at #{format_added_at(rule.inserted_at, @site.timezone)} by #{rule.added_by}"}
                  >
                    <%= country.flag %> <%= country.name %>
                  </span>
                </div>
              </.td>
              <.td hide_on_mobile>
                <span :if={rule.action == :deny}>
                  Blocked
                </span>
                <span :if={rule.action == :allow}>
                  Allowed
                </span>
              </.td>
              <.td actions>
                <.delete_button
                  id={"remove-country-rule-#{rule.id}"}
                  phx-target={@myself}
                  phx-click="remove-country-rule"
                  phx-value-rule-id={rule.id}
                  data-confirm="Are you sure you want to revoke this rule?"
                />
              </.td>
            </:tbody>
          </.table>

          <.live_component :let={modal_unique_id} module={Modal} id="country-rule-form-modal">
            <.form
              :let={f}
              for={@form}
              phx-submit="save-country-rule"
              phx-target={@myself}
              class="max-w-md w-full mx-auto bg-white dark:bg-gray-800"
            >
              <.title>Add Country to Block List</.title>

              <.live_component
                class="mt-4"
                submit_name="country_rule[country_code]"
                submit_value={f[:country_code].value}
                display_value=""
                module={PlausibleWeb.Live.Components.ComboBox}
                suggest_fun={&PlausibleWeb.Live.Components.ComboBox.StaticSearch.suggest/2}
                id={"#{f[:country_code].id}-#{modal_unique_id}"}
                suggestions_limit={300}
                options={options(@country_rules)}
              />

              <p class="mt-4 text-sm text-gray-500 dark:text-gray-400">
                Once added, we will start rejecting traffic from this country within a few minutes.
              </p>
              <.button type="submit" class="w-full">
                Add Country
              </.button>
            </.form>
          </.live_component>
        </.tile>
      </.settings_tiles>
    </div>
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
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end
end
