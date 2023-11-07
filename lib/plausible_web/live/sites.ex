defmodule PlausibleWeb.Live.Sites do
  @moduledoc """
  LiveView for sites index.
  """

  use Phoenix.LiveView
  use Phoenix.HTML

  import PlausibleWeb.Components.Generic
  import PlausibleWeb.Live.Components.Pagination

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Sites

  def mount(params, %{"current_user_id" => user_id}, socket) do
    uri =
      ("/sites?" <> URI.encode_query(Map.take(params, ["filter_text"])))
      |> URI.new!()

    socket =
      socket
      |> assign(:uri, uri)
      |> assign(:filter_text, params["filter_text"] || "")
      |> assign(:user, Repo.get!(Auth.User, user_id))

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:params, params)
      |> load_sites()
      |> assign_new(:has_sites?, fn %{user: user} ->
        Site.Memberships.any_or_pending?(user)
      end)
      |> assign_new(:needs_to_upgrade, fn %{user: user, sites: sites} ->
        user_owns_sites =
          Enum.any?(sites.entries, fn site ->
            List.first(site.memberships ++ site.invitations).role == :owner
          end) ||
            Auth.user_owns_sites?(user)

        user_owns_sites && Plausible.Billing.check_needs_to_upgrade(user)
      end)

    {:noreply, socket}
  end

  def render(assigns) do
    invitations =
      assigns.sites.entries
      |> Enum.filter(&(&1.entry_type == "invitation"))
      |> Enum.flat_map(& &1.invitations)

    assigns = assign(assigns, :invitations, invitations)

    ~H"""
    <.live_component id="embedded_liveview_flash" module={PlausibleWeb.Live.Flash} flash={@flash} />
    <div
      x-data={"{selectedInvitation: null, invitationOpen: false, invitations: #{Enum.map(@invitations, &({&1.invitation_id, &1})) |> Enum.into(%{}) |> Jason.encode!}}"}
      x-on:keydown.escape.window="invitationOpen = false"
      class="container pt-6"
    >
      <PlausibleWeb.Live.Components.Visitors.gradient_defs />
      <.upgrade_nag_screen :if={@needs_to_upgrade == {:needs_to_upgrade, :no_active_subscription}} />

      <div class="mt-6 pb-5 border-b border-gray-200 dark:border-gray-500 flex items-center justify-between">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 dark:text-gray-100 sm:text-3xl sm:leading-9 sm:truncate flex-shrink-0">
          My Sites
        </h2>
      </div>

      <div class="border-t border-gray-200 pt-4 sm:flex sm:items-center sm:justify-between">
        <.search_form :if={@has_sites?} filter_text={@filter_text} uri={@uri} />
        <p :if={not @has_sites?} class="dark:text-gray-100">
          You don't have any sites yet.
        </p>
        <div class="mt-4 flex sm:ml-4 sm:mt-0">
          <a href="/sites/new" class="button">
            + Add Website
          </a>
        </div>
      </div>

      <p
        :if={String.trim(@filter_text) != "" and @sites.entries == []}
        class="mt-4 dark:text-gray-100"
      >
        No sites found. Please search for something else.
      </p>

      <div :if={@has_sites?}>
        <ul class="my-6 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <%= for site <- @sites.entries do %>
            <.site
              :if={site.entry_type == "site"}
              site={site}
              hourly_stats={@hourly_stats[site.domain]}
            />
            <.invitation
              :if={site.entry_type == "invitation"}
              site={site}
              invitation={hd(site.invitations)}
              hourly_stats={@hourly_stats[site.domain]}
            />
          <% end %>
        </ul>

        <.pagination
          :if={@sites.total_pages > 1}
          id="sites-pagination"
          uri={@uri}
          page_number={@sites.page_number}
          total_pages={@sites.total_pages}
        >
          Total of <span class="font-medium"><%= @sites.total_entries %></span> sites
        </.pagination>
        <.invitation_modal
          :if={Enum.any?(@sites.entries, &(&1.entry_type == "invitation"))}
          user={@user}
        />
      </div>
    </div>
    """
  end

  def upgrade_nag_screen(assigns) do
    ~H"""
    <div class="rounded-md bg-yellow-100 p-4">
      <div class="flex">
        <div class="flex-shrink-0">
          <svg
            class="h-5 w-5 text-yellow-400"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
              clip-rule="evenodd"
            />
          </svg>
        </div>
        <div class="ml-3">
          <h3 class="text-sm font-medium text-yellow-800">
            Payment required
          </h3>
          <div class="mt-2 text-sm text-yellow-700">
            <p>
              To access the sites you own, you need to subscribe to a monthly or yearly payment plan. <%= link(
                "Upgrade now →",
                to: "/settings",
                class: "text-sm font-medium text-yellow-800"
              ) %>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :site, Plausible.Site, required: true
  attr :invitation, Plausible.Auth.Invitation, required: true
  attr :hourly_stats, :map, required: true

  def invitation(assigns) do
    ~H"""
    <li
      class="group cursor-pointer"
      id={"site-card-#{@site.domain}"}
      data-domain={@site.domain}
      x-on:click={"invitationOpen = true; selectedInvitation = invitations['#{@invitation.invitation_id}']"}
    >
      <div class="col-span-1 bg-white dark:bg-gray-800 rounded-lg shadow p-4 group-hover:shadow-lg cursor-pointer">
        <div class="w-full flex items-center justify-between space-x-4">
          <img
            src={"/favicon/sources/#{@site.domain}"}
            onerror="this.onerror=null; this.src='/favicon/sources/placeholder';"
            class="w-4 h-4 flex-shrink-0 mt-px"
          />
          <div class="flex-1 truncate -mt-px">
            <h3 class="text-gray-900 font-medium text-lg truncate dark:text-gray-100">
              <%= @site.domain %>
            </h3>
          </div>

          <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
            Pending invitation
          </span>
        </div>
        <.site_stats hourly_stats={@hourly_stats} />
      </div>
    </li>
    """
  end

  attr :site, Plausible.Site, required: true
  attr :hourly_stats, :map, required: true

  def site(assigns) do
    ~H"""
    <li class="group relative" id={"site-card-#{@site.domain}"} data-domain={@site.domain}>
      <.unstyled_link href={"/#{URI.encode_www_form(@site.domain)}"}>
        <div class="col-span-1 bg-white dark:bg-gray-800 rounded-lg shadow p-4 group-hover:shadow-lg cursor-pointer">
          <div class="w-full flex items-center justify-between space-x-4">
            <.favicon domain={@site.domain} />
            <div class="flex-1 -mt-px w-full">
              <h3
                class="text-gray-900 font-medium text-lg truncate dark:text-gray-100"
                style="width: calc(100% - 4rem)"
              >
                <%= @site.domain %>
              </h3>
            </div>
          </div>
          <.site_stats hourly_stats={@hourly_stats} />
        </div>
      </.unstyled_link>

      <.ellipsis_menu site={@site} />
    </li>
    """
  end

  def ellipsis_menu(assigns) do
    ~H"""
    <div x-data="dropdown">
      <a
        x-on:click="toggle()"
        x-ref="button"
        x-bind:aria-expanded="open"
        x-bind:aria-controls="$id('dropdown-button')"
        class="absolute top-0 right-0 h-10 w-10 rounded-md hover:cursor-pointer hover:bg-gray-100 dark:hover:bg-indigo-900"
      >
        <Heroicons.ellipsis_vertical
          class="absolute top-3 right-3 w-4 h-4 text-gray-800 dark:text-gray-400"
          aria-expanded="false"
          aria-haspopup="true"
        />
      </a>

      <div
        x-ref="panel"
        x-show="open"
        x-bind:id="$id('dropdown-button')"
        x-on:click.outside="close($refs.button)"
        x-on:click="onPanelClick"
        x-transition.origin.top.right
        x-transition.duration.100ms
        class="absolute top-7 right-3 z-10 mt-2 w-40 origin-top-right rounded-md bg-white dark:bg-gray-900 shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none"
        style="display: none;"
        role="menu"
        aria-orientation="vertical"
        aria-label={"#{@site.domain} menu button"}
        tabindex="-1"
      >
        <div class="py-1 text-sm" role="none">
          <.unstyled_link
            :if={List.first(@site.memberships).role != :viewer}
            href={"/#{URI.encode_www_form(@site.domain)}/settings"}
            class="text-gray-500 flex px-4 py-2 hover:bg-gray-100 hover:text-gray-800 dark:text-gray-500 dark:hover:text-gray-100 dark:hover:bg-indigo-900 cursor-pointer"
            role="menuitem"
            tabindex="-1"
          >
            <Heroicons.cog_6_tooth class="mr-3 h-5 w-5" />
            <span>Settings</span>
          </.unstyled_link>

          <button
            type="button"
            class="w-full text-gray-500 flex px-4 py-2 hover:bg-gray-100 hover:text-gray-800 dark:text-gray-500 dark:hover:text-gray-100 dark:hover:bg-indigo-900 cursor-pointer"
            role="menuitem"
            tabindex="-1"
            x-on:click="close($refs.button)"
            phx-click="pin-toggle"
            phx-value-domain={@site.domain}
          >
            <.icon_pin
              :if={@site.pinned_at}
              class="pt-1 mr-3 h-5 w-5 text-red-400 stroke-red-500 dark:text-yellow-600 dark:stroke-yellow-700"
            />
            <span :if={@site.pinned_at}>Unpin Site</span>

            <.icon_pin :if={!@site.pinned_at} class="pt-1 mr-3 h-5 w-5" />
            <span :if={!@site.pinned_at}>Pin Site</span>
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :rest, :global

  def icon_pin(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="16"
      height="16"
      fill="currentColor"
      viewBox="0 0 16 16"
      {@rest}
    >
      <path d="M9.828.722a.5.5 0 0 1 .354.146l4.95 4.95a.5.5 0 0 1 0 .707c-.48.48-1.072.588-1.503.588-.177 0-.335-.018-.46-.039l-3.134 3.134a5.927 5.927 0 0 1 .16 1.013c.046.702-.032 1.687-.72 2.375a.5.5 0 0 1-.707 0l-2.829-2.828-3.182 3.182c-.195.195-1.219.902-1.414.707-.195-.195.512-1.22.707-1.414l3.182-3.182-2.828-2.829a.5.5 0 0 1 0-.707c.688-.688 1.673-.767 2.375-.72a5.922 5.922 0 0 1 1.013.16l3.134-3.133a2.772 2.772 0 0 1-.04-.461c0-.43.108-1.022.589-1.503a.5.5 0 0 1 .353-.146z" />
    </svg>
    """
  end

  attr :hourly_stats, :map, required: true

  def site_stats(assigns) do
    ~H"""
    <div class="md:h-[78px] h-20 pl-8 pr-8 pt-2">
      <div :if={@hourly_stats == :loading} class="text-center animate-pulse">
        <div class="md:h-[34px] h-11 dark:bg-gray-700 bg-gray-100 rounded-md"></div>
        <div class="md:h-[26px] h-6 mt-1 dark:bg-gray-700 bg-gray-100 rounded-md"></div>
      </div>
      <div
        :if={is_map(@hourly_stats)}
        class="hidden h-50px"
        phx-mounted={
          Phoenix.LiveView.JS.show(transition: {"ease-in duration-500", "opacity-0", "opacity-100"})
        }
      >
        <span class="text-gray-600 dark:text-gray-400 text-sm truncate">
          <PlausibleWeb.Live.Components.Visitors.chart intervals={@hourly_stats.intervals} />
          <div class="flex justify-between items-center">
            <p>
              <span class="text-gray-800 dark:text-gray-200">
                <b><%= PlausibleWeb.StatsView.large_number_format(@hourly_stats.visitors) %></b>
                visitor<span :if={@hourly_stats.visitors != 1}>s</span> in last 24h
              </span>
            </p>

            <.percentage_change change={@hourly_stats.change} />
          </div>
        </span>
      </div>
    </div>
    """
  end

  attr :change, :integer, required: true

  def percentage_change(assigns) do
    ~H"""
    <p class="dark:text-gray-100">
      <span :if={@change == 0} class="font-semibold">〰</span>
      <span :if={@change > 0} class="font-semibold text-green-500">↑</span>
      <span :if={@change < 0} class="font-semibold text-red-400">↓</span>
      <%= abs(@change) %>%
    </p>
    """
  end

  attr :user, Plausible.Auth.User, required: true

  def invitation_modal(assigns) do
    ~H"""
    <div
      x-cloak
      x-show="invitationOpen"
      class="fixed z-10 inset-0 overflow-y-auto"
      aria-labelledby="modal-title"
      role="dialog"
      aria-modal="true"
    >
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div
          x-show="invitationOpen"
          x-transition:enter="transition ease-out duration-300"
          x-transition:enter-start="opacity-0"
          x-transition:enter-end="opacity-100"
          x-transition:leave="transition ease-in duration-200"
          x-transition:leave-start="opacity-100"
          x-transition:leave-end="opacity-0"
          class="fixed inset-0 bg-gray-500 dark:bg-gray-800 bg-opacity-75 dark:bg-opacity-75 transition-opacity"
          aria-hidden="true"
          x-on:click="invitationOpen = false"
        >
        </div>
        <!-- This element is to trick the browser into centering the modal contents. -->
        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">
          &#8203;
        </span>

        <div
          x-show="invitationOpen"
          x-transition:enter="transition ease-out duration-300"
          x-transition:enter-start="opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
          x-transition:enter-end="opacity-100 translate-y-0 sm:scale-100"
          x-transition:leave="transition ease-in duration-200"
          x-transition:leave-start="opacity-100 translate-y-0 sm:scale-100"
          x-transition:leave-end="opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
          class="inline-block align-bottom bg-white dark:bg-gray-900 rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full"
        >
          <div class="bg-white dark:bg-gray-800 px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
            <div class="hidden sm:block absolute top-0 right-0 pt-4 pr-4">
              <button
                x-on:click="invitationOpen = false"
                class="bg-white dark:bg-gray-800 rounded-md text-gray-400 dark:text-gray-500 hover:text-gray-500 dark:hover:text-gray-400 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                <span class="sr-only">Close</span>
                <Heroicons.x_mark class="h-6 w-6" />
              </button>
            </div>
            <div class="sm:flex sm:items-start">
              <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-green-100 sm:mx-0 sm:h-10 sm:w-10">
                <Heroicons.user_group class="h-6 w-6" />
              </div>
              <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left">
                <h3
                  class="text-lg leading-6 font-medium text-gray-900 dark:text-gray-100"
                  id="modal-title"
                >
                  Invitation for
                  <span x-text="selectedInvitation && selectedInvitation.site.domain"></span>
                </h3>
                <div class="mt-2">
                  <p class="text-sm text-gray-500 dark:text-gray-200">
                    You've been invited to the
                    <span x-text="selectedInvitation && selectedInvitation.site.domain"></span>
                    analytics dashboard as <b
                      class="capitalize"
                      x-text="selectedInvitation && selectedInvitation.role"
                    >Admin</b>.
                  </p>
                  <p
                    x-show="selectedInvitation && selectedInvitation.role === 'owner'"
                    class="mt-2 text-sm text-gray-500 dark:text-gray-200"
                  >
                    If you accept the ownership transfer, you will be responsible for billing going forward.
                    <div
                      :if={is_nil(@user.trial_expiry_date) and is_nil(@user.subscription)}
                      class="mt-4"
                    >
                      You will have to enter your card details immediately with no 30-day trial.
                    </div>
                    <div :if={Plausible.Billing.on_trial?(@user)} class="mt-4">
                      <Heroicons.exclamation_triangle class="w-4 h-4 inline-block text-red-500" />
                      Your 30-day free trial will end immediately and
                      <strong>you will have to enter your card details</strong>
                      to keep using Plausible.
                    </div>
                  </p>
                </div>
              </div>
            </div>
          </div>
          <div class="bg-gray-50 dark:bg-gray-850 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
            <button
              class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-700 sm:ml-3 sm:w-auto sm:text-sm"
              data-method="post"
              data-csrf={Plug.CSRFProtection.get_csrf_token()}
              x-bind:data-to="selectedInvitation && ('/sites/invitations/' + selectedInvitation.invitation_id + '/accept')"
            >
              Accept &amp; Continue
            </button>
            <button
              type="button"
              class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 dark:border-gray-500 shadow-sm px-4 py-2 bg-white dark:bg-gray-800 text-base font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-850 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
              data-method="post"
              data-csrf={Plug.CSRFProtection.get_csrf_token()}
              x-bind:data-to="selectedInvitation && ('/sites/invitations/' + selectedInvitation.invitation_id + '/reject')"
            >
              Reject
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :filter_text, :string, default: ""
  attr :uri, URI, required: true

  def search_form(assigns) do
    ~H"""
    <form id="filter-form" phx-change="filter" action={@uri} method="GET">
      <div class="text-gray-800 text-sm inline-flex items-center">
        <div class="relative rounded-md flex">
          <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
            <Heroicons.magnifying_glass class="feather mr-1 dark:text-gray-300" />
          </div>
          <input
            type="text"
            name="filter_text"
            id="filter-text"
            phx-debounce={200}
            class="pl-8 dark:bg-gray-900 dark:text-gray-300 focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:bg-gray-800"
            placeholder="Press / to search sites"
            autocomplete="off"
            value={@filter_text}
            x-ref="filter_text"
            x-on:keydown.escape="$refs.filter_text.blur(); $refs.reset_filter?.dispatchEvent(new Event('click', {bubbles: true, cancelable: true}));"
            x-on:keydown.prevent.slash.window="$refs.filter_text.focus(); $refs.filter_text.select();"
            x-on:blur="$refs.filter_text.placeholder = 'Press / to search sites';"
            x-on:focus="$refs.filter_text.placeholder = 'Search sites';"
          />
        </div>

        <button
          :if={String.trim(@filter_text) != ""}
          class="phx-change-loading:hidden ml-2"
          phx-click="reset-filter-text"
          id="reset-filter"
          x-ref="reset_filter"
          type="button"
        >
          <Heroicons.backspace class="feather hover:text-red-500 dark:text-gray-300 dark:hover:text-red-500" />
        </button>

        <.spinner class="hidden phx-change-loading:inline ml-2" />
      </div>
    </form>
    """
  end

  def favicon(assigns) do
    src = "/favicon/sources/#{assigns.domain}"
    assigns = assign(assigns, :src, src)

    ~H"""
    <img src={@src} class="w-4 h-4 flex-shrink-0 mt-px" />
    """
  end

  attr :class, :any, default: ""

  def spinner(assigns) do
    ~H"""
    <svg
      class={["animate-spin h-4 w-4 text-indigo-500", @class]}
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
    >
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4">
      </circle>
      <path
        className="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
      >
      </path>
    </svg>
    """
  end

  def handle_event("pin-toggle", %{"domain" => domain}, socket) do
    site = Enum.find(socket.assigns.sites.entries, &(&1.domain == domain))

    if site do
      preference = Sites.toggle_pin(socket.assigns.user, site)

      flash_message =
        if preference.options.pinned_at do
          "Site pinned"
        else
          "Site unpinned"
        end

      socket = put_flash(socket, :success, flash_message)

      Process.send_after(self(), :clear_flash, 5000)
      {:noreply, load_sites(socket)}
    else
      Sentry.capture_message("Attempting to toggle pin for invalid domain.",
        extra: %{domain: domain, user: socket.assigns.user.id}
      )

      {:noreply, socket}
    end
  end

  def handle_event(
        "filter",
        %{"filter_text" => filter_text},
        %{assigns: %{filter_text: filter_text}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_event("filter", %{"filter_text" => filter_text}, socket) do
    socket =
      socket
      |> reset_pagination()
      |> set_filter_text(filter_text)

    {:noreply, socket}
  end

  def handle_event("reset-filter-text", _params, socket) do
    socket =
      socket
      |> reset_pagination()
      |> set_filter_text("")

    {:noreply, socket}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  defp load_sites(%{assigns: assigns} = socket) do
    sites =
      Sites.list_with_invitations(assigns.user, assigns.params,
        filter_by_domain: assigns.filter_text
      )

    hourly_stats =
      if connected?(socket) do
        Plausible.Stats.Clickhouse.last_24h_visitors_hourly_intervals(sites.entries)
      else
        sites.entries
        |> Enum.into(%{}, fn site ->
          {site.domain, :loading}
        end)
      end

    assign(
      socket,
      sites: sites,
      hourly_stats: hourly_stats
    )
  end

  defp set_filter_text(socket, filter_text) do
    uri = socket.assigns.uri

    uri_params =
      uri.query
      |> URI.decode_query()
      |> Map.put("filter_text", filter_text)
      |> URI.encode_query()

    uri = %{uri | query: uri_params}

    socket
    |> assign(:filter_text, filter_text)
    |> assign(:uri, uri)
    |> push_patch(to: URI.to_string(uri), replace: true)
  end

  defp reset_pagination(socket) do
    pagination_fields = ["page"]
    uri = socket.assigns.uri

    uri_params =
      uri.query
      |> URI.decode_query()
      |> Map.drop(pagination_fields)
      |> URI.encode_query()

    assign(socket,
      uri: %{uri | query: uri_params},
      params: Map.drop(socket.assigns.params, pagination_fields)
    )
  end
end
