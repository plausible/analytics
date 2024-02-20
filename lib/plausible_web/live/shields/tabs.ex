defmodule PlausibleWeb.Live.Shields.Tabs do
  @moduledoc """
  Currently only a placeholder module. Once more shields
  are implemented it will display tabs with counters,
  linking to their respective live views.
  """
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  alias Plausible.Shields
  alias Plausible.Sites

  def mount(
        _params,
        %{
          "remote_ip" => remote_ip,
          "domain" => domain,
          "current_user_id" => user_id,
          "selected_shield" => shield
        },
        socket
      ) do
    socket =
      socket
      |> assign(:selected_shield, shield)
      |> assign_new(:site, fn ->
        Sites.get_for_user!(user_id, domain, [:owner, :admin, :super_admin])
      end)
      |> assign_new(:ip_rules_count, fn %{site: site} ->
        Shields.count_ip_rules(site)
      end)
      |> assign_new(:country_rules_count, fn %{site: _site} ->
        0
      end)
      |> assign_new(:current_user, fn ->
        Plausible.Repo.get(Plausible.Auth.User, user_id)
      end)
      |> assign_new(:remote_ip, fn -> remote_ip end)
      |> assign(:current_tab, :ip_rules)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.flash_messages flash={@flash} />

      <div id="shield-tabs" class="mb-4">
        <div class="sm:hidden">
          <label for="tabs" class="sr-only">Select a tab</label>
          <!-- Use an "onChange" listener to redirect the user to the selected tab URL. -->
          <!-- TODO: dark mode in the mobile picker -->
          <select
            id="tabs"
            name="tabs"
            class="block w-full rounded-md border-gray-300 py-2 pl-3 pr-10 text-base focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm"
          >
            <option selected>IP Addresses (<%= @ip_rules_count %>)</option>
            <option>Countries (<%= @country_rules_count %>)</option>
          </select>
        </div>
        <div class="hidden sm:block">
          <div class="border-b border-gray-200 dark:border-gray-700">
            <nav class="-mb-px flex space-x-8" aria-label="Tabs">
              <.tab
                site={@site}
                shield="ip"
                selected={@selected_shield}
                label="IP Addresses"
                counter={@ip_rules_count}
              />
              <.tab
                site={@site}
                shield="country"
                selected={@selected_shield}
                label="Countries"
                counter={@country_rules_count}
              />
            </nav>
          </div>
        </div>
      </div>

      <.ip_rules
        :if={@selected_shield == "ip"}
        current_user={@current_user}
        remote_ip={@remote_ip}
        site={@site}
        ip_rules_count={@ip_rules_count}
      />
    </div>
    """
  end

  def tab(assigns) do
    ~H"""
    <a href={tab_href(@site, @shield)} class={tab_class(@shield, @selected)}>
      <%= @label %>
      <span class={tab_counter_class(@shield, @selected)}>
        <%= @counter %>
      </span>
    </a>
    """
  end

  def ip_rules(assigns) do
    ~H"""
    <.live_component
      module={PlausibleWeb.Live.Shields.IPRules}
      current_user={@current_user}
      ip_rules_count={@ip_rules_count}
      site={@site}
      remote_ip={@remote_ip}
      id="ip-rules-#{@current_user.id}"
    />
    """
  end

  def handle_info({:flash, kind, message}, socket) do
    socket = put_live_flash(socket, kind, message)
    {:noreply, socket}
  end

  def handle_info({:update, assigns}, socket) do
    socket = assign(socket, assigns)
    {:noreply, socket}
  end

  defp tab_href(site, shield) do
    Routes.site_path(PlausibleWeb.Endpoint, :settings_shields, site.domain, shield)
  end

  defp tab_class(shield, selected) do
    if selected == shield do
      "border-indigo-500 text-indigo-600 flex whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium dark:text-gray-100"
    else
      "border-transparent text-gray-500  hover:text-gray-700 flex whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium dark:text-gray-400 dark:hover:text-gray-300"
    end
  end

  defp tab_counter_class(shield, selected) do
    if selected == shield do
      "bg-indigo-100 text-indigo-600 ml-3 hidden rounded-full py-0.5 px-2.5 text-xs font-medium md:inline-block dark:bg-indigo-600 dark:text-gray-100"
    else
      "bg-gray-100 text-gray-900 ml-3 hidden rounded-full py-0.5 px-2.5 text-xs font-medium md:inline-block dark:bg-gray-800 dark:text-gray-500"
    end
  end
end
