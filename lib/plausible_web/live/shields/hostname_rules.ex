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
  import PlausibleWeb.Components.Generic

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
    <div>
      <.settings_tiles>
        <.tile docs="excluding#exclude-visits-by-hostname">
          <:title>Hostnames Allow List</:title>
          <:subtitle>Accept incoming traffic only from familiar hostnames</:subtitle>
          <.filter_bar
            :if={@hostname_rules_count < Shields.maximum_hostname_rules()}
            filtering_enabled?={false}
          >
            <.button
              id="add-hostname-rule"
              x-data
              x-on:click={Modal.JS.open("hostname-rule-form-modal")}
              mt?={false}
            >
              Add Hostname
            </.button>
          </.filter_bar>

          <.notice
            :if={@hostname_rules_count >= Shields.maximum_hostname_rules()}
            class="mt-4"
            title="Maximum number of hostnames reached"
            theme={:gray}
          >
            <p>
              You've reached the maximum number of hostnames you can block (<%= Shields.maximum_hostname_rules() %>). Please remove one before adding another.
            </p>
          </.notice>

          <p :if={Enum.empty?(@hostname_rules)} class="mt-12 mb-8 text-center text-sm">
            No Hostname Rules configured for this site.
            <strong>
              Traffic from all hostnames is currently accepted.
            </strong>
          </p>

          <.table :if={not Enum.empty?(@hostname_rules)} rows={@hostname_rules}>
            <:thead>
              <.th>Hostname</.th>
              <.th hide_on_mobile>Status</.th>
              <.th invisible>Actions</.th>
            </:thead>
            <:tbody :let={rule}>
              <.td>
                <div class="flex items-center">
                  <span
                    id={"hostname-#{rule.id}"}
                    class="mr-4 cursor-help text-ellipsis truncate max-w-xs"
                    title={"Added at #{format_added_at(rule.inserted_at, @site.timezone)} by #{rule.added_by}"}
                  >
                    <%= rule.hostname %>
                  </span>
                </div>
              </.td>
              <.td hide_on_mobile>
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
                    class="pl-4 cursor-help"
                  >
                    <Heroicons.exclamation_triangle class="h-5 w-5 text-red-800" />
                  </span>
                </div>
              </.td>
              <.td actions>
                <.delete_button
                  id={"remove-hostname-rule-#{rule.id}"}
                  phx-target={@myself}
                  phx-click="remove-hostname-rule"
                  phx-value-rule-id={rule.id}
                  data-confirm="Are you sure you want to revoke this rule?"
                />
              </.td>
            </:tbody>
          </.table>

          <.live_component :let={modal_unique_id} module={Modal} id="hostname-rule-form-modal">
            <.form
              :let={f}
              for={@form}
              phx-submit="save-hostname-rule"
              phx-target={@myself}
              class="max-w-md w-full mx-auto bg-white dark:bg-gray-800"
            >
              <.title>Add Hostname to Allow List</.title>

              <.live_component
                class="mt-8"
                submit_name="hostname_rule[hostname]"
                submit_value={f[:hostname].value}
                display_value={f[:hostname].value || ""}
                module={PlausibleWeb.Live.Components.ComboBox}
                suggest_fun={fn input, options -> suggest_hostnames(input, options, @site) end}
                id={"#{f[:hostname].id}-#{modal_unique_id}"}
                creatable
              />

              <%= error_tag(f, :hostname) %>

              <p class="mt-4 text-sm text-gray-500 dark:text-gray-400">
                You can use a wildcard (<code>*</code>) to match multiple hostnames. For example,
                <code>*<%= @site.domain %></code>
                will only record traffic on your main domain and all of its subdomains.<br /><br />

                <%= if @hostname_rules_count >= 1 do %>
                  Once added, we will start accepting traffic from this hostname within a few minutes.
                <% else %>
                  NB: Once added, we will start rejecting traffic from non-matching hostnames within a few minutes.
                <% end %>
              </p>
              <.button type="submit" class="w-full">
                Add Hostname
              </.button>
            </.form>
          </.live_component>
        </.tile>
      </.settings_tiles>
    </div>
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
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
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
