defmodule PlausibleWeb.Live.Shields.HostnameRules do
  @moduledoc """
  LiveView allowing hostname Rules management
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
        hostname_rules_count: assigns.hostname_rules_count,
        site: assigns.site,
        current_user: assigns.current_user,
        form: new_form()
      )
      |> assign_new(:hostname_rules, fn %{site: site} ->
        Shields.list_hostname_rules(site)
      end)
      |> assign_new(:redundant_rules, fn %{hostname_rules: hostname_rules} ->
        detect_redundancy(hostname_rules)
      end)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <section class="shadow bg-white dark:bg-gray-800 sm:rounded-md sm:overflow-hidden">
      <div class="py-6 px-4 sm:p-6">
        <header class="relative">
          <h2 class="text-lg leading-6 font-medium text-gray-900 dark:text-gray-100">
            Hostnames Allow List
          </h2>
          <p class="mt-1 mb-4 text-sm leading-5 text-gray-500 dark:text-gray-200">
            Accept incoming traffic only from familiar hostnames.
          </p>

          <PlausibleWeb.Components.Generic.docs_info slug="excluding#exclude-visits-by-hostname" />
        </header>
        <div class="border-t border-gray-200 pt-4 grid">
          <div
            :if={@hostname_rules_count < Shields.maximum_hostname_rules()}
            class="mt-4 sm:ml-4 sm:mt-0 justify-self-end"
          >
            <PlausibleWeb.Components.Generic.button
              id="add-hostname-rule"
              x-data
              x-on:click={Modal.JS.open("hostname-rule-form-modal")}
            >
              + Add Hostname
            </PlausibleWeb.Components.Generic.button>
          </div>
          <PlausibleWeb.Components.Generic.notice
            :if={@hostname_rules_count >= Shields.maximum_hostname_rules()}
            class="mt-4"
            title="Maximum number of hostnames reached"
          >
            <p>
              You've reached the maximum number of hostnames you can block (<%= Shields.maximum_hostname_rules() %>). Please remove one before adding another.
            </p>
          </PlausibleWeb.Components.Generic.notice>
        </div>

        <.live_component module={Modal} id="hostname-rule-form-modal">
          <.form
            :let={f}
            for={@form}
            phx-submit="save-hostname-rule"
            phx-target={@myself}
            class="max-w-md w-full mx-auto bg-white dark:bg-gray-800"
          >
            <h2 class="text-xl font-black dark:text-gray-100 mb-8">Add Hostname to Allow List</h2>

            <.live_component
              submit_name="hostname_rule[hostname]"
              submit_value={f[:hostname].value}
              display_value={f[:hostname].value || ""}
              module={PlausibleWeb.Live.Components.ComboBox}
              suggest_fun={fn input, options -> suggest_hostnames(input, options, @site) end}
              id={f[:hostname].id}
              creatable
            />

            <%= error_tag(f, :hostname) %>

            <p class="text-sm mt-2 text-gray-500 dark:text-gray-200">
              You can use a wildcard (<code>*</code>) to match multiple hostnames. For example,
              <code>*.<%= @site.domain %></code>
              will match all subdomains.<br /><br />

              <%= if @hostname_rules_count >= 1 do %>
                Once added, we will start accepting traffic from this hostname within a few minutes.
              <% else %>
                NB: Once added, we will start rejecting traffic from non-matching hostnames within a few minutes.
              <% end %>
            </p>
            <div class="py-4 mt-8">
              <PlausibleWeb.Components.Generic.button type="submit" class="w-full">
                Add Hostname →
              </PlausibleWeb.Components.Generic.button>
            </div>
          </.form>
        </.live_component>

        <p
          :if={Enum.empty?(@hostname_rules)}
          class="text-sm text-gray-800 dark:text-gray-200 mt-12 mb-8 text-center"
        >
          No Hostname Rules configured for this Site.<br /><br />
          <strong>
            Traffic from all hostnames is currently accepted.
          </strong>
        </p>
        <div
          :if={not Enum.empty?(@hostname_rules)}
          class="mt-8 overflow-hidden border-b border-gray-200 shadow dark:border-gray-900 sm:rounded-lg"
        >
          <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-900">
            <thead class="bg-gray-50 dark:bg-gray-900">
              <tr>
                <th
                  scope="col"
                  class="px-6 py-3 text-xs font-medium text-left text-gray-500 uppercase dark:text-gray-100"
                >
                  hostname
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
              <%= for rule <- @hostname_rules do %>
                <tr class="text-gray-900 dark:text-gray-100">
                  <td class="px-6 py-4 text-sm font-medium max-w-xs truncate text-ellipsis overflow-hidden">
                    <div class="flex items-center">
                      <span
                        id={"hostname-#{rule.id}"}
                        class="mr-4 cursor-help border-b border-dotted border-gray-400 text-ellipsis overflow-hidden"
                        title={"#{rule.hostname}\n\nAdded at #{format_added_at(rule.inserted_at, @site.timezone)} by #{rule.added_by}"}
                      >
                        <%= rule.hostname %>
                      </span>
                    </div>
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-500">
                    <div class="flex items-center">
                      <span :if={rule.action == :deny}>
                        Blocked
                      </span>
                      <span :if={rule.action == :allow} class="text-green-500">
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
                      id={"remove-hostname-rule-#{rule.id}"}
                      phx-target={@myself}
                      phx-click="remove-hostname-rule"
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

  def handle_event("save-hostname-rule", %{"hostname_rule" => params}, socket) do
    user = socket.assigns.current_user

    case Shields.add_hostname_rule(
           socket.assigns.site.id,
           params,
           added_by: user
         ) do
      {:ok, rule} ->
        hostname_rules = [rule | socket.assigns.hostname_rules]

        socket =
          socket
          |> Modal.close("hostname-rule-form-modal")
          |> assign(
            form: new_form(),
            hostname_rules: hostname_rules,
            hostname_rules_count: socket.assigns.hostname_rules_count + 1,
            redundant_rules: detect_redundancy(hostname_rules)
          )

        # Make sure to clear the combobox input after adding a hostname rule, on subsequent modal reopening
        send_update(PlausibleWeb.Live.Components.ComboBox,
          id: "hostname_rule_hostname_code",
          display_value: ""
        )

        send_flash(
          :success,
          "Hostname rule added successfully. Traffic will be limited within a few minutes."
        )

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("remove-hostname-rule", %{"rule-id" => rule_id}, socket) do
    Shields.remove_hostname_rule(socket.assigns.site.id, rule_id)

    send_flash(
      :success,
      "Hostname rule removed successfully. Traffic will be re-adjusted within a few minutes."
    )

    hostname_rules = Enum.reject(socket.assigns.hostname_rules, &(&1.id == rule_id))

    {:noreply,
     socket
     |> assign(
       hostname_rules_count: socket.assigns.hostname_rules_count - 1,
       hostname_rules: hostname_rules,
       redundant_rules: detect_redundancy(hostname_rules)
     )}
  end

  def send_flash(kind, message) do
    send(self(), {:flash, kind, message})
  end

  defp new_form() do
    %Shield.HostnameRule{}
    |> Shield.HostnameRule.changeset(%{})
    |> to_form()
  end

  defp format_added_at(dt, tz) do
    dt
    |> Plausible.Timezones.to_datetime_in_timezone(tz)
    |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:{m}:{s}")
  end

  def suggest_hostnames(input, _options, site) do
    query = Plausible.Stats.Query.from(site, %{})

    site
    |> Plausible.Stats.filter_suggestions(query, "hostname", input)
    |> Enum.map(fn %{label: label, value: value} -> {label, value} end)
  end

  defp detect_redundancy(hostname_rules) do
    hostname_rules
    |> Enum.reduce(%{}, fn rule, acc ->
      {[^rule], remaining_rules} =
        Enum.split_with(
          hostname_rules,
          fn r -> r == rule end
        )

      conflicting =
        remaining_rules
        |> Enum.filter(fn candidate ->
          rule
          |> Map.fetch!(:hostname_pattern)
          |> maybe_compile()
          |> Regex.match?(candidate.hostname)
        end)
        |> Enum.map(& &1.id)

      Enum.reduce(conflicting, acc, fn conflicting_rule_id, acc ->
        Map.update(acc, conflicting_rule_id, [rule.hostname], fn existing ->
          [rule.hostname | existing]
        end)
      end)
    end)
  end

  defp maybe_compile(pattern) when is_binary(pattern), do: Regex.compile!(pattern)
  defp maybe_compile(%Regex{} = pattern), do: pattern
end
