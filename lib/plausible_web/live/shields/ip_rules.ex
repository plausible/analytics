defmodule PlausibleWeb.Live.Shields.IPRules do
  @moduledoc """
  LiveView allowing IP Rules management
  """

  use Phoenix.LiveComponent, global_prefixes: ~w(x-)
  use Phoenix.HTML

  alias PlausibleWeb.Live.Components.Modal
  alias Plausible.Shields
  alias Plausible.Shield
  import PlausibleWeb.Live.Components.Form
  import PlausibleWeb.Components.Generic

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
    <section class="shadow bg-white dark:bg-gray-800 sm:rounded-md sm:overflow-hidden">
      <div class="py-6 px-4 sm:p-6">
        <header class="relative">
          <h2 class="text-lg leading-6 font-medium text-gray-900 dark:text-gray-100">
            IP Block List
          </h2>
          <p class="mt-1 mb-4 text-sm leading-5 text-gray-500 dark:text-gray-200">
            Reject incoming traffic from specific IP addresses
          </p>

          <PlausibleWeb.Components.Generic.docs_info slug="excluding" />
        </header>
        <div class="border-t border-gray-200 pt-4 grid">
          <div
            :if={@ip_rules_count < Shields.maximum_ip_rules()}
            class="mt-4 sm:ml-4 sm:mt-0 justify-self-end"
          >
            <PlausibleWeb.Components.Generic.button
              id="add-ip-rule"
              x-data
              x-on:click={Modal.JS.open("ip-rule-form-modal")}
            >
              + Add IP Address
            </PlausibleWeb.Components.Generic.button>
          </div>
          <PlausibleWeb.Components.Generic.notice
            :if={@ip_rules_count >= Shields.maximum_ip_rules()}
            class="mt-4"
            title="Maximum number of addresses reached"
          >
            <p>
              You've reached the maximum number of IP addresses you can block (<%= Shields.maximum_ip_rules() %>). Please remove one before adding another.
            </p>
          </PlausibleWeb.Components.Generic.notice>
        </div>

        <.live_component module={Modal} id="ip-rule-form-modal">
          <.form
            :let={f}
            for={@form}
            phx-submit="save-ip-rule"
            phx-target={@myself}
            class="max-w-md w-full mx-auto bg-white dark:bg-gray-800"
          >
            <h2 class="text-xl font-black dark:text-gray-100 mb-8">Add IP to Block List</h2>

            <.input
              autofocus
              field={f[:inet]}
              label="IP Address"
              class="focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-900 dark:text-gray-300 block w-7/12 rounded-md sm:text-sm border-gray-300 dark:border-gray-500 w-full p-2 mt-2"
              placeholder="e.g. 192.168.127.12"
            />

            <div class="mt-4">
              <p
                :if={not ip_rule_present?(@ip_rules, @remote_ip)}
                class="text-sm text-gray-500 dark:text-gray-200 mb-4"
              >
                Your current IP address is: <span class="font-mono"><%= @remote_ip %></span>
                <br />
                <.styled_link phx-target={@myself} phx-click="prefill-own-ip-rule">
                  Click here
                </.styled_link>
                to block your own traffic, or enter a custom address.
              </p>
            </div>

            <.input
              field={f[:description]}
              label="Description"
              class="focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-900 dark:text-gray-300 block w-7/12 rounded-md sm:text-sm border-gray-300 dark:border-gray-500 w-full p-2 mt-2"
              placeholder="e.g. The Office"
            />

            <p class="text-sm mt-2 text-gray-500 dark:text-gray-200">
              Once added, we will start rejecting traffic from this IP within a few minutes.
            </p>
            <div class="py-4 mt-8">
              <PlausibleWeb.Components.Generic.button type="submit" class="w-full">
                Add IP Address →
              </PlausibleWeb.Components.Generic.button>
            </div>
          </.form>
        </.live_component>

        <p
          :if={Enum.empty?(@ip_rules)}
          class="text-sm text-gray-800 dark:text-gray-200 mt-12 mb-8 text-center"
        >
          No IP Rules configured for this Site.
        </p>
        <div
          :if={not Enum.empty?(@ip_rules)}
          class="mt-8 overflow-hidden border-b border-gray-200 shadow dark:border-gray-900 sm:rounded-lg"
        >
          <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-900">
            <thead class="bg-gray-50 dark:bg-gray-900">
              <tr>
                <th
                  scope="col"
                  class="px-6 py-3 text-xs font-medium text-left text-gray-500 uppercase dark:text-gray-100"
                >
                  IP Address
                </th>
                <th
                  scope="col"
                  class="px-6 py-3 text-xs font-medium text-left text-gray-500 uppercase dark:text-gray-100"
                >
                  Status
                </th>
                <th
                  scope="col"
                  class="px-6 py-3 text-xs font-medium text-left text-gray-500 uppercase dark:text-gray-100 md:block hidden"
                >
                  Description
                </th>
                <th scope="col" class="px-6 py-3">
                  <span class="sr-only">Remove</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <%= for rule <- @ip_rules do %>
                <tr class="text-gray-900 dark:text-gray-100">
                  <td class="px-6 py-4 text-xs font-medium">
                    <div class="flex items-center">
                      <span
                        id={"inet-#{rule.id}"}
                        class="font-mono mr-4 cursor-help border-b border-dotted border-gray-400"
                        title={"Added at #{format_added_at(rule.inserted_at, @site.timezone)} by #{rule.added_by}"}
                      >
                        <%= rule.inet %>
                      </span>

                      <span
                        :if={to_string(rule.inet) == @remote_ip}
                        class="inline-flex items-center gap-x-1.5 rounded-md px-2 py-1 text-xs font-medium text-gray-700 dark:text-white ring-1 ring-inset ring-gray-300 dark:ring-gray-700"
                      >
                        <svg class="h-1.5 w-1.5 fill-green-400" viewBox="0 0 6 6" aria-hidden="true">
                          <circle cx="3" cy="3" r="3" />
                        </svg>
                        YOU
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
                  <td class="px-6 py-4 text-sm font-normal whitespace-nowrap truncate max-w-xs md:block hidden">
                    <span :if={rule.description} title={rule.description}>
                      <%= rule.description %>
                    </span>
                    <span :if={!rule.description} class="text-gray-400 dark:text-gray-600">
                      --
                    </span>
                  </td>
                  <td class="px-6 py-4 text-sm font-medium text-right">
                    <button
                      id={"remove-ip-rule-#{rule.id}"}
                      phx-target={@myself}
                      phx-click="remove-ip-rule"
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
    |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:{m}:{s}")
  end
end
