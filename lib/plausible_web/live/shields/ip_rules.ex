defmodule PlausibleWeb.Live.Shields.IPRules do
  @moduledoc """
  LiveView allowing IP Rules management
  """

  use PlausibleWeb, :live_component

  alias PlausibleWeb.Live.Components.Modal
  alias Plausible.Shields
  alias Plausible.Shield

  def update(assigns, socket) do
    socket =
      socket
      |> assign(
        ip_rules_count: assigns.ip_rules_count,
        remote_ip: assigns.remote_ip,
        site: assigns.site,
        current_user: assigns.current_user,
        form: new_form()
      )
      |> assign_new(:ip_rules, fn %{site: site} ->
        Shields.list_ip_rules(site)
      end)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.settings_tiles>
        <.tile docs="excluding">
          <:title>IP Block List</:title>
          <:subtitle>Reject incoming traffic from specific IP addresses</:subtitle>
          <.filter_bar :if={@ip_rules_count < Shields.maximum_ip_rules()} filtering_enabled?={false}>
            <.button
              id="add-ip-rule"
              x-data
              x-on:click={Modal.JS.open("ip-rule-form-modal")}
              mt?={false}
            >
              Add IP Address
            </.button>
          </.filter_bar>

          <.notice
            :if={@ip_rules_count >= Shields.maximum_ip_rules()}
            class="mt-4"
            title="Maximum number of addresses reached"
            theme={:gray}
          >
            <p>
              You've reached the maximum number of IP addresses you can block ({Shields.maximum_ip_rules()}). Please remove one before adding another.
            </p>
          </.notice>

          <p :if={Enum.empty?(@ip_rules)} class="mt-12 mb-8 text-center text-sm">
            No IP Rules configured for this site.
          </p>

          <.table :if={not Enum.empty?(@ip_rules)} rows={@ip_rules}>
            <:thead>
              <.th>IP Address</.th>
              <.th hide_on_mobile>Status</.th>
              <.th hide_on_mobile>Description</.th>
              <.th invisible>Actions</.th>
            </:thead>
            <:tbody :let={rule}>
              <.td max_width="max-w-40">
                <div class="flex items-center truncate">
                  <span
                    :if={to_string(rule.inet) == @remote_ip}
                    class="inline-flex items-center gap-x-1.5 rounded-md px-2 mr-2 py-1 text-xs font-medium text-gray-700 dark:text-white ring-1 ring-inset ring-gray-300 dark:ring-gray-700"
                  >
                    <svg class="h-1.5 w-1.5 fill-green-400" viewBox="0 0 6 6" aria-hidden="true">
                      <circle cx="3" cy="3" r="3" />
                    </svg>
                    YOU
                  </span>
                  <span
                    id={"inet-#{rule.id}"}
                    class="cursor-help"
                    title={"Added at #{format_added_at(rule.inserted_at, @site.timezone)} by #{rule.added_by}"}
                  >
                    {rule.inet}
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
              <.td hide_on_mobile truncate>
                <span :if={rule.description} title={rule.description}>
                  {rule.description}
                </span>
                <span :if={!rule.description} class="text-gray-400 dark:text-gray-600">
                  --
                </span>
              </.td>
              <.td actions>
                <.delete_button
                  id={"remove-ip-rule-#{rule.id}"}
                  phx-target={@myself}
                  phx-click="remove-ip-rule"
                  phx-value-rule-id={rule.id}
                  data-confirm="Are you sure you want to revoke this rule?"
                />
              </.td>
            </:tbody>
          </.table>

          <.live_component module={Modal} id="ip-rule-form-modal">
            <.form
              :let={f}
              for={@form}
              phx-submit="save-ip-rule"
              phx-target={@myself}
              class="max-w-md w-full mx-auto bg-white dark:bg-gray-800"
            >
              <.title>Add IP to Block List</.title>

              <div class="mt-4">
                <p
                  :if={not ip_rule_present?(@ip_rules, @remote_ip)}
                  class="text-sm text-gray-500 dark:text-gray-400 mb-4"
                >
                  Your current IP address is: <span class="font-mono"><%= @remote_ip %></span>.
                  <.styled_link phx-target={@myself} phx-click="prefill-own-ip-rule">
                    Click here
                  </.styled_link>
                  to block your own traffic, or enter a custom address below.
                </p>

                <.input
                  autofocus
                  field={f[:inet]}
                  label="IP Address"
                  placeholder="e.g. 192.168.127.12"
                />
              </div>

              <.input
                field={f[:description]}
                label="Description (optional)"
                placeholder="e.g. The Office"
              />

              <p class="mt-4 text-sm text-gray-500 dark:text-gray-400">
                Once added, we will start rejecting traffic from this IP within a few minutes.
              </p>
              <.button type="submit" class="w-full">
                Add IP Address →
              </.button>
            </.form>
          </.live_component>
        </.tile>
      </.settings_tiles>
    </div>
    """
  end

  def handle_event("prefill-own-ip-rule", %{}, socket) do
    form =
      %Plausible.Shield.IPRule{}
      |> Plausible.Shield.IPRule.changeset(%{
        inet: socket.assigns.remote_ip,
        description: socket.assigns.current_user.name
      })
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save-ip-rule", %{"ip_rule" => params}, socket) do
    user = socket.assigns.current_user

    case Shields.add_ip_rule(
           socket.assigns.site.id,
           params,
           added_by: user
         ) do
      {:ok, rule} ->
        socket =
          socket
          |> Modal.close("ip-rule-form-modal")
          |> assign(
            form: new_form(),
            ip_rules: [rule | socket.assigns.ip_rules],
            ip_rules_count: socket.assigns.ip_rules_count + 1
          )

        send_flash(
          :success,
          "IP rule added successfully. Traffic will be rejected within a few minutes."
        )

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("remove-ip-rule", %{"rule-id" => rule_id}, socket) do
    Shields.remove_ip_rule(socket.assigns.site.id, rule_id)

    send_flash(
      :success,
      "IP rule removed successfully. Traffic will be resumed within a few minutes."
    )

    {:noreply,
     socket
     |> assign(
       ip_rules_count: socket.assigns.ip_rules_count - 1,
       ip_rules: Enum.reject(socket.assigns.ip_rules, &(&1.id == rule_id))
     )}
  end

  def send_flash(kind, message) do
    send(self(), {:flash, kind, message})
  end

  defp new_form() do
    %Shield.IPRule{}
    |> Shield.IPRule.changeset(%{})
    |> to_form()
  end

  defp ip_rule_present?(rules, ip) do
    not is_nil(Enum.find(rules, &(to_string(&1.inet) == ip)))
  end

  defp format_added_at(dt, tz) do
    dt
    |> Plausible.Timezones.to_datetime_in_timezone(tz)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end
end
