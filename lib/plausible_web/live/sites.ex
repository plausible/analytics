defmodule PlausibleWeb.Live.Sites do
  @moduledoc """
  LiveView for sites index.
  """

  use PlausibleWeb, :live_view
  import PlausibleWeb.Live.Components.Pagination
  import PlausibleWeb.StatsView, only: [large_number_format: 1]
  require Logger

  alias Plausible.Sites
  alias Plausible.Teams

  alias PlausibleWeb.Components.PrimaDropdown

  def mount(params, _session, socket) do
    team = socket.assigns.current_team
    user = socket.assigns.current_user

    uri =
      ("/sites?" <> URI.encode_query(Map.take(params, ["filter_text"])))
      |> URI.new!()

    socket =
      socket
      |> assign(:uri, uri)
      |> assign(
        :team_invitations,
        Teams.Invitations.all(user)
      )
      |> assign(:hourly_stats, %{})
      |> assign(:filter_text, String.trim(params["filter_text"] || ""))
      |> assign(init_consolidated_view_assigns(user, team))

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:params, params)
      |> load_sites()
      |> assign_new(:has_sites?, fn %{current_user: current_user} ->
        Teams.Users.has_sites?(current_user, include_pending?: true)
      end)
      |> assign_new(:needs_to_upgrade, fn %{
                                            current_user: current_user,
                                            current_team: current_team
                                          } ->
        current_team &&
          Teams.Users.owns_sites?(current_user, include_pending?: true, only_team: current_team) &&
          Teams.Billing.check_needs_to_upgrade(current_team)
      end)

    {:noreply, socket}
  end

  def render(assigns) do
    assigns =
      assign(
        assigns,
        :invitations_map,
        Enum.map(assigns.invitations, &{&1.invitation.invitation_id, &1}) |> Enum.into(%{})
      )

    ~H"""
    <.flash_messages flash={@flash} />
    <div class="container pt-6">
      <PlausibleWeb.Live.Components.Visitors.gradient_defs />
      <.upgrade_nag_screen :if={
        @needs_to_upgrade == {:needs_to_upgrade, :no_active_trial_or_subscription}
      } />

      <div class="group mt-6 pb-5 border-b border-gray-200 dark:border-gray-750 flex items-center justify-between">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 dark:text-gray-100 sm:text-3xl sm:leading-9 sm:truncate shrink-0">
          {Teams.name(@current_team)}
          <.unstyled_link
            :if={Teams.setup?(@current_team)}
            data-test-id="team-settings-link"
            href={Routes.settings_path(@socket, :team_general)}
          >
            <Heroicons.cog_6_tooth class="hidden group-hover:inline size-5 dark:text-gray-100 text-gray-900" />
          </.unstyled_link>
        </h2>
      </div>

      <PlausibleWeb.Team.Notice.team_invitations team_invitations={@team_invitations} />

      <div class="pt-4 sm:flex sm:items-center sm:justify-between">
        <.search_form :if={@has_sites?} filter_text={@filter_text} uri={@uri} />
        <p :if={not @has_sites?} class="dark:text-gray-100">
          You don't have any sites yet.
        </p>
        <!-- The `z-49` class is to make the dropdown appear above the site cards and (TODO) below the top-right drop down. -->
          <!-- The proper solution is for Prima to render the dropdown menu within a <.portal> element to avoid -->
          <!-- any stacking context issues. TODO  -->
        <PrimaDropdown.dropdown
          :if={@consolidated_view_cta_dismissed?}
          class="z-[49]"
          id="add-site-dropdown"
        >
          <PrimaDropdown.dropdown_trigger as={&button/1} mt?={false}>
            + Add <Heroicons.chevron_down mini class="size-4 mt-0.5" />
          </PrimaDropdown.dropdown_trigger>

          <PrimaDropdown.dropdown_menu>
            <PrimaDropdown.dropdown_item
              as={&link/1}
              href={Routes.site_path(@socket, :new, %{flow: PlausibleWeb.Flows.provisioning()})}
            >
              + Add website
            </PrimaDropdown.dropdown_item>
            <PrimaDropdown.dropdown_item phx-click="consolidated-view-cta-restore">
              + Add consolidated view
            </PrimaDropdown.dropdown_item>
          </PrimaDropdown.dropdown_menu>
        </PrimaDropdown.dropdown>

        <a
          :if={!@consolidated_view_cta_dismissed?}
          href={"/sites/new?flow=#{PlausibleWeb.Flows.provisioning()}"}
          class="whitespace-nowrap truncate inline-flex items-center justify-center gap-x-2 font-medium rounded-md px-3.5 py-2.5 text-sm transition-all duration-150 cursor-pointer disabled:cursor-not-allowed bg-indigo-600 text-white hover:bg-indigo-700 focus-visible:outline-indigo-600 disabled:bg-indigo-400/60 disabled:dark:bg-indigo-600/30 disabled:dark:text-white/35"
        >
          + Add website
        </a>
      </div>

      <p :if={@filter_text != "" and @sites.entries == []} class="mt-4 dark:text-gray-100 text-center">
        No sites found. Please search for something else.
      </p>

      <p
        :if={
          @has_sites? and not Teams.setup?(@current_team) and @sites.entries == [] and
            @filter_text == ""
        }
        class="mt-4 dark:text-gray-100 text-center"
      >
        You currently have no personal sites. Are you looking for your team’s sites?
        <.styled_link href={Routes.auth_path(@socket, :select_team)}>
          Go to your team &rarr;
        </.styled_link>
      </p>

      <div :if={@has_sites?}>
        <ul class="my-6 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <.consolidated_view_card_cta
            :if={
              !@consolidated_view and @no_consolidated_view_reason not in [:no_sites, :unavailable] and
                not @consolidated_view_cta_dismissed?
            }
            can_manage_consolidated_view?={@can_manage_consolidated_view?}
            no_consolidated_view_reason={@no_consolidated_view_reason}
            current_user={@current_user}
            current_team={@current_team}
          />
          <.consolidated_view_card
            :if={@consolidated_view && consolidated_view_ok_to_display?(@current_team, @current_user)}
            can_manage_consolidated_view?={@can_manage_consolidated_view?}
            consolidated_view={@consolidated_view}
            consolidated_stats={@consolidated_stats}
            current_user={@current_user}
            current_team={@current_team}
          />
          <%= for site <- @sites.entries do %>
            <.site
              :if={site.entry_type in ["pinned_site", "site"]}
              site={site}
              hourly_stats={Map.get(@hourly_stats, site.domain, :loading)}
            />
            <.invitation
              :if={site.entry_type == "invitation"}
              site={site}
              invitation={@invitations_map[hd(site.invitations).invitation_id]}
              hourly_stats={Map.get(@hourly_stats, site.domain, :loading)}
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
          Total of <span class="font-medium">{@sites.total_entries}</span> sites
        </.pagination>
      </div>
    </div>
    """
  end

  def upgrade_nag_screen(assigns) do
    ~H"""
    <div class="rounded-md bg-yellow-100 dark:bg-yellow-900/40 p-5">
      <div class="flex">
        <div class="shrink-0">
          <svg
            class="size-5 mt-0.5 text-yellow-500"
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
        <div class="ml-2">
          <h3 class="font-medium text-gray-900 dark:text-gray-100">
            Payment required
          </h3>
          <div class="mt-1 text-sm text-gray-900/80 dark:text-gray-100/60">
            <p>
              To access the sites you own, you need to subscribe to a monthly or yearly payment plan.
              <.styled_link href={Routes.settings_path(PlausibleWeb.Endpoint, :subscription)}>
                Upgrade now →
              </.styled_link>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def consolidated_view_card_cta(assigns) do
    ~H"""
    <li
      data-test-id="consolidated-view-card-cta"
      class="relative col-span-1 flex flex-col justify-between bg-white p-6 dark:bg-gray-800 rounded-md shadow-lg dark:shadow-xl"
    >
      <div class="flex flex-col">
        <p class="text-sm text-gray-600 dark:text-gray-400">
          Introducing
        </p>
        <h3 class="text-[1.35rem] font-bold text-gray-900 leading-tighter dark:text-gray-100">
          Consolidated view
        </h3>
      </div>

      <div
        :if={@no_consolidated_view_reason == :team_not_setup}
        class="flex flex-col gap-y-4"
      >
        <p class="text-gray-900 dark:text-gray-100 leading-tighter">
          To create a consolidated view, you'll need to set up a team.
        </p>
        <div class="flex gap-x-2">
          <.button_link
            href={Routes.team_setup_path(PlausibleWeb.Endpoint, :setup)}
            mt?={false}
          >
            Create team
          </.button_link>
          <.button_link
            theme="secondary"
            href="https://plausible.io/docs/consolidated-views"
            mt?={false}
          >
            Learn more
          </.button_link>
        </div>
      </div>

      <div
        :if={@no_consolidated_view_reason == :upgrade_required}
        class="flex flex-col gap-y-4"
      >
        <p
          :if={@can_manage_consolidated_view?}
          class="text-gray-900 dark:text-gray-100 leading-tighter"
        >
          Upgrade to the Business plan<span :if={not Teams.setup?(@current_team)}> and set up a team</span> to enable consolidated views.
        </p>

        <p
          :if={not @can_manage_consolidated_view?}
          class="text-gray-900 dark:text-gray-100 leading-tighter"
        >
          Available on Business plans. Contact your team owner to create it.
        </p>

        <div class="flex gap-x-2">
          <.button_link
            :if={@can_manage_consolidated_view?}
            href={PlausibleWeb.Router.Helpers.billing_url(PlausibleWeb.Endpoint, :choose_plan)}
            mt?={false}
          >
            Upgrade
          </.button_link>

          <.button_link
            theme="secondary"
            href="https://plausible.io/docs/consolidated-views"
            mt?={false}
          >
            Learn more
          </.button_link>
        </div>
      </div>
      <a phx-click="consolidated-view-cta-dismiss">
        <Heroicons.x_mark class="absolute top-6 right-6 size-5 text-gray-400 transition-colors duration-150 cursor-pointer dark:text-gray-400 hover:text-gray-500 dark:hover:text-gray-300" />
      </a>
    </li>
    """
  end

  def consolidated_view_card(assigns) do
    ~H"""
    <li
      data-test-id="consolidated-view-card"
      class="relative row-span-2 bg-white p-6 dark:bg-gray-900 rounded-md shadow-sm cursor-pointer hover:shadow-lg transition-shadow duration-150"
    >
      <.unstyled_link
        href={"/#{URI.encode_www_form(@consolidated_view.domain)}"}
        class="flex flex-col justify-between gap-6 h-full"
      >
        <div class="flex flex-col flex-1 justify-between gap-y-5">
          <div class="flex flex-col gap-y-2 mb-auto">
            <span class="size-8 sm:size-10 bg-indigo-600 text-white p-1.5 sm:p-2 rounded-lg sm:rounded-xl">
              <.globe_icon />
            </span>
            <h3 class="text-gray-900 font-medium text-md sm:text-lg leading-tight dark:text-gray-100">
              All sites
            </h3>
          </div>
          <span
            :if={is_map(@consolidated_stats)}
            class="h-[54px] text-indigo-500 my-auto"
            data-test-id="consolidated-view-chart-loaded"
          >
            <PlausibleWeb.Live.Components.Visitors.chart
              intervals={@consolidated_stats.intervals}
              height={80}
            />
          </span>
        </div>
        <div
          :if={is_map(@consolidated_stats)}
          data-test-id="consolidated-view-stats-loaded"
          class="flex flex-col flex-1 justify-between gap-y-2.5 sm:gap-y-5"
        >
          <div class="flex flex-col sm:flex-row justify-between gap-2.5 sm:gap-2 flex-1 w-full">
            <.consolidated_view_stat
              value={large_number_format(@consolidated_stats.visitors)}
              label="Unique visitors"
              change={@consolidated_stats.visitors_change}
            />
            <.consolidated_view_stat
              value={large_number_format(@consolidated_stats.visits)}
              label="Total visits"
              change={@consolidated_stats.visits_change}
            />
          </div>
          <div class="flex flex-col sm:flex-row justify-between gap-2.5 sm:gap-2 flex-1 w-full">
            <.consolidated_view_stat
              value={large_number_format(@consolidated_stats.pageviews)}
              label="Total pageviews"
              change={@consolidated_stats.pageviews_change}
            />
            <.consolidated_view_stat
              value={@consolidated_stats.views_per_visit}
              label="Views per visit"
              change={@consolidated_stats.views_per_visit_change}
            />
          </div>
        </div>
        <div
          :if={@consolidated_stats == :loading}
          class="flex flex-col gap-y-2 min-h-[254px] h-full text-center animate-pulse"
          data-test-id="consolidated-viw-stats-loading"
        >
          <div class="flex-2 dark:bg-gray-750 bg-gray-100 rounded-md"></div>
          <div class="flex-1 flex flex-col gap-y-2">
            <div class="w-full h-full dark:bg-gray-750 bg-gray-100 rounded-md"></div>
            <div class="w-full h-full dark:bg-gray-750 bg-gray-100 rounded-md"></div>
          </div>
        </div>
      </.unstyled_link>
      <div :if={@can_manage_consolidated_view?} class="absolute right-1 top-3.5">
        <.ellipsis_menu site={@consolidated_view} can_manage?={true} />
      </div>
    </li>
    """
  end

  attr(:value, :string, required: true)
  attr(:label, :string, required: true)
  attr(:change, :integer, required: true)

  def consolidated_view_stat(assigns) do
    ~H"""
    <div class="flex flex-col flex-1 sm:gap-y-1.5">
      <p class="text-sm text-gray-600 dark:text-gray-400">
        {@label}
      </p>
      <div class="flex w-full justify-between items-baseline sm:flex-col sm:justify-start sm:items-start">
        <p class="text-lg sm:text-xl font-bold text-gray-900 dark:text-gray-100">
          {@value}
        </p>

        <.percentage_change change={@change} />
      </div>
    </div>
    """
  end

  attr(:site, Plausible.Site, required: true)
  attr(:invitation, :map, required: true)
  attr(:hourly_stats, :map, required: true)

  def invitation(assigns) do
    assigns =
      assigns
      |> assign(:modal_id, "invitation-modal-#{assigns[:invitation].invitation.invitation_id}")

    ~H"""
    <li
      class="group relative cursor-pointer"
      id={"site-card-#{hash_domain(@site.domain)}"}
      data-domain={@site.domain}
      phx-click={Prima.Modal.open(@modal_id)}
    >
      <div class="col-span-1 flex flex-col gap-y-5 bg-white dark:bg-gray-900 rounded-md shadow-sm p-6 group-hover:shadow-lg cursor-pointer transition duration-100">
        <div class="w-full flex items-center justify-between gap-x-2.5">
          <.favicon domain={@site.domain} />
          <div class="flex-1 w-full truncate">
            <h3 class="text-gray-900 font-medium text-md sm:text-lg leading-[22px] truncate dark:text-gray-100">
              {@site.domain}
            </h3>
          </div>
          <span class="inline-flex items-center -my-1 px-2 py-1 rounded-sm bg-green-100 text-green-800 text-xs font-medium leading-normal dark:bg-green-900/40 dark:text-green-400">
            Pending invitation
          </span>
        </div>
        <.site_stats hourly_stats={@hourly_stats} />
      </div>
      <.invitation_modal id={@modal_id} site={@site} invitation={@invitation} />
    </li>
    """
  end

  attr(:site, Plausible.Site, required: true)
  attr(:hourly_stats, :map, required: true)

  def site(assigns) do
    ~H"""
    <li
      class="group relative"
      id={"site-card-#{hash_domain(@site.domain)}"}
      data-domain={@site.domain}
      data-pin-toggled={
        JS.show(
          transition: {"duration-500", "opacity-0 shadow-2xl -translate-y-6", "opacity-100 shadow"},
          time: 400
        )
      }
      data-pin-failed={
        JS.show(
          transition: {"duration-500", "opacity-0", "opacity-100"},
          time: 200
        )
      }
    >
      <.unstyled_link href={"/#{URI.encode_www_form(@site.domain)}"}>
        <div class="col-span-1 flex flex-col gap-y-5 bg-white dark:bg-gray-900 rounded-md shadow-sm p-6 group-hover:shadow-lg cursor-pointer transition duration-100">
          <div class="w-full flex items-center justify-between gap-x-2.5">
            <.favicon domain={@site.domain} />
            <div class="flex-1 w-full">
              <h3
                class="text-gray-900 font-medium text-md sm:text-lg leading-[22px] truncate dark:text-gray-100"
                style="width: calc(100% - 4rem)"
              >
                {@site.domain}
              </h3>
            </div>
          </div>
          <.site_stats hourly_stats={@hourly_stats} />
        </div>
      </.unstyled_link>

      <div class="absolute right-1 top-3.5">
        <.ellipsis_menu site={@site} can_manage?={List.first(@site.memberships).role != :viewer} />
      </div>
    </li>
    """
  end

  def ellipsis_menu(assigns) do
    ~H"""
    <.dropdown>
      <:button class="size-10 rounded-md hover:cursor-pointer text-gray-400 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-100">
        <Heroicons.ellipsis_vertical class="absolute top-3 right-3 size-5 transition-colors duration-150" />
      </:button>
      <:menu class="!mt-0 mr-4 min-w-40">
        <!-- adjust position because click area is much bigger than icon. Default positioning from click area looks weird -->
        <.dropdown_item
          :if={@can_manage?}
          href={"/#{URI.encode_www_form(@site.domain)}/settings/general"}
          class="group/item !flex items-center gap-x-2"
        >
          <Heroicons.cog_6_tooth class="size-5 text-gray-600 dark:text-gray-400 group-hover/item:text-gray-900 dark:group-hover/item:text-gray-100 transition-colors duration-150" />
          <span>Settings</span>
        </.dropdown_item>

        <.dropdown_item
          :if={Sites.regular?(@site)}
          href="#"
          x-on:click.prevent
          phx-click={
            JS.hide(
              transition: {"duration-500", "opacity-100", "opacity-0"},
              to: "#site-card-#{hash_domain(@site.domain)}",
              time: 500
            )
            |> JS.push("pin-toggle")
          }
          phx-value-domain={@site.domain}
          class="group/item !flex items-center gap-x-2"
        >
          <.icon_pin
            :if={@site.pinned_at}
            filled={true}
            class="size-[1.15rem] text-indigo-600 dark:text-indigo-500 group-hover/item:text-indigo-700 dark:group-hover/item:text-indigo-400 transition-colors duration-150"
          />
          <span :if={@site.pinned_at}>Unpin site</span>

          <.icon_pin
            :if={!@site.pinned_at}
            class="size-5 text-gray-600 dark:text-gray-400 group-hover/item:text-gray-900 dark:group-hover/item:text-gray-100 transition-colors duration-150"
          />
          <span :if={!@site.pinned_at}>Pin site</span>
        </.dropdown_item>
        <.dropdown_item
          :if={Application.get_env(:plausible, :environment) == "dev" and Sites.regular?(@site)}
          href={Routes.site_path(PlausibleWeb.Endpoint, :delete_site, @site.domain)}
          method="delete"
          class="group/item !flex items-center gap-x-2"
        >
          <Heroicons.trash class="size-5 text-red-500" />
          <span class="text-red-500">[DEV ONLY] Quick delete</span>
        </.dropdown_item>
      </:menu>
    </.dropdown>
    """
  end

  attr(:rest, :global)
  attr(:filled, :boolean, default: false)

  def icon_pin(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill={if @filled, do: "currentColor", else: "none"}
      stroke="currentColor"
      stroke-linecap="round"
      stroke-linejoin="round"
      stroke-width="1.5"
      {@rest}
    >
      <path d="m4 20 4.5-4.5-.196.196M14.314 21.005l-5.657-5.657L3 9.69l1.228-1.228a3 3 0 0 1 3.579-.501l.58.322 7.34-5.664 5.658 5.657-5.665 7.34.323.581a3 3 0 0 1-.501 3.578l-1.228 1.229Z" />
    </svg>
    """
  end

  attr(:hourly_stats, :any, required: true)

  def site_stats(assigns) do
    ~H"""
    <div class={[
      "flex flex-col gap-y-2 h-[122px] text-center animate-pulse",
      is_map(@hourly_stats) && " hidden"
    ]}>
      <div class="flex-2 dark:bg-gray-750 bg-gray-100 rounded-md"></div>
      <div class="flex-1 dark:bg-gray-750 bg-gray-100 rounded-md"></div>
    </div>
    <div :if={is_map(@hourly_stats)}>
      <span class="flex flex-col gap-y-5 text-gray-600 dark:text-gray-400 text-sm truncate">
        <span class="h-[54px] text-indigo-500">
          <PlausibleWeb.Live.Components.Visitors.chart
            intervals={@hourly_stats.intervals}
            height={80}
          />
        </span>
        <div class="flex justify-between items-end">
          <div class="flex flex-col">
            <p class="text-lg sm:text-xl font-bold text-gray-900 dark:text-gray-100">
              {large_number_format(@hourly_stats.visitors)}
            </p>
            <p class="text-gray-600 dark:text-gray-400">
              visitor<span :if={@hourly_stats.visitors != 1}>s</span> in last 24h
            </p>
          </div>

          <.percentage_change change={@hourly_stats.change} />
        </div>
      </span>
    </div>
    """
  end

  attr(:change, :integer, required: true)

  # Related React component: <ChangeArrow />
  def percentage_change(assigns) do
    ~H"""
    <p class="text-gray-900 dark:text-gray-100">
      <svg
        :if={@change > 0}
        xmlns="http://www.w3.org/2000/svg"
        fill="currentColor"
        viewBox="0 0 24 24"
        class="text-green-500 h-3 w-3 inline-block stroke-[1px] stroke-current"
      >
        <path
          fill-rule="evenodd"
          d="M8.25 3.75H19.5a.75.75 0 01.75.75v11.25a.75.75 0 01-1.5 0V6.31L5.03 20.03a.75.75 0 01-1.06-1.06L17.69 5.25H8.25a.75.75 0 010-1.5z"
          clip-rule="evenodd"
        >
        </path>
      </svg>
      <svg
        :if={@change < 0}
        xmlns="http://www.w3.org/2000/svg"
        fill="currentColor"
        viewBox="0 0 24 24"
        class="text-red-400 h-3 w-3 inline-block stroke-[1px] stroke-current"
      >
        <path
          fill-rule="evenodd"
          d="M3.97 3.97a.75.75 0 011.06 0l13.72 13.72V8.25a.75.75 0 011.5 0V19.5a.75.75 0 01-.75.75H8.25a.75.75 0 010-1.5h9.44L3.97 5.03a.75.75 0 010-1.06z"
          clip-rule="evenodd"
        >
        </path>
      </svg>

      {PlausibleWeb.TextHelpers.number_format(abs(@change))}%
    </p>
    """
  end

  attr(:id, :string, required: true)
  attr(:site, Plausible.Site, required: true)
  attr(:invitation, :map, required: true)

  def invitation_modal(assigns) do
    ~H"""
    <PlausibleWeb.Live.Components.PrimaModal.modal id={@id}>
      <div class="bg-white dark:bg-gray-850 px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
        <div class="hidden sm:block absolute top-0 right-0 pt-4 pr-4">
          <button
            phx-click={Prima.Modal.close()}
            class="bg-white dark:bg-gray-800 rounded-md text-gray-400 dark:text-gray-500 hover:text-gray-500 dark:hover:text-gray-400 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-indigo-500"
          >
            <span class="sr-only">Close</span>
            <Heroicons.x_mark class="size-6" />
          </button>
        </div>
        <div class="sm:flex sm:items-start">
          <div class="mx-auto shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-green-100 sm:mx-0 sm:h-10 sm:w-10">
            <Heroicons.user_group class="size-6" />
          </div>
          <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left">
            <PlausibleWeb.Live.Components.PrimaModal.modal_title>
              Invitation for {@site.domain}
            </PlausibleWeb.Live.Components.PrimaModal.modal_title>
            <div class="mt-2">
              <p class="text-sm text-gray-500 dark:text-gray-200">
                You've been invited to the {@site.domain} analytics dashboard as <b class="capitalize">{@invitation.invitation.role}</b>.
              </p>
              <div
                :if={
                  !(Map.get(@invitation, :exceeded_limits) || Map.get(@invitation, :no_plan)) &&
                    @invitation.invitation.role == :owner
                }
                class="mt-2 text-sm text-gray-500 dark:text-gray-200"
              >
                If you accept the ownership transfer, you will be responsible for billing going forward.
              </div>
            </div>
          </div>
        </div>
        <.notice
          :if={Map.get(@invitation, :missing_features)}
          title="Missing features"
          class="mt-4 shadow-xs dark:shadow-none"
        >
          <p>
            The site uses {Map.get(@invitation, :missing_features)},
            which your current subscription does not support. After accepting ownership of this site,
            you will not be able to access them unless you <.styled_link
              class="inline-block"
              href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
            >
              upgrade to a suitable plan
            </.styled_link>.
          </p>
        </.notice>
        <.notice
          :if={Map.get(@invitation, :exceeded_limits)}
          title="Unable to accept site ownership"
          class="mt-4 shadow-xs dark:shadow-none"
        >
          <p>
            Owning this site would exceed your {Map.get(@invitation, :exceeded_limits)}. Please check your usage in
            <.styled_link
              class="inline-block"
              href={Routes.settings_path(PlausibleWeb.Endpoint, :subscription)}
            >
              account settings
            </.styled_link>
            and upgrade your subscription to accept the site ownership.
          </p>
        </.notice>
        <.notice
          :if={Map.get(@invitation, :no_plan)}
          title="No subscription"
          class="mt-4 shadow-xs dark:shadow-none"
        >
          You are unable to accept the ownership of this site because your account does not have a subscription. To become the owner of this site, you should upgrade to a suitable plan.
        </.notice>
      </div>
      <div class="bg-gray-50 dark:bg-gray-850 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
        <.button
          :if={!(Map.get(@invitation, :exceeded_limits) || Map.get(@invitation, :no_plan))}
          mt?={false}
          class="sm:ml-3 w-full sm:w-auto sm:text-sm"
          data-method="post"
          data-csrf={Plug.CSRFProtection.get_csrf_token()}
          data-to={"/sites/invitations/#{@invitation.invitation.invitation_id}/accept"}
          data-autofocus
        >
          Accept &amp; Continue
        </.button>
        <.button_link
          :if={Map.get(@invitation, :exceeded_limits) || Map.get(@invitation, :no_plan)}
          mt?={false}
          href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
          class="sm:ml-3 w-full sm:w-auto sm:text-sm"
          data-autofocus
        >
          Upgrade
        </.button_link>
        <.button_link
          mt?={false}
          class="w-full sm:w-auto mr-2 sm:text-sm mt-2 sm:mt-0"
          href="#"
          theme="secondary"
          data-method="post"
          data-csrf={Plug.CSRFProtection.get_csrf_token()}
          data-to={"/sites/invitations/#{@invitation.invitation.invitation_id}/reject"}
        >
          Reject
        </.button_link>
      </div>
    </PlausibleWeb.Live.Components.PrimaModal.modal>
    """
  end

  attr(:filter_text, :string, default: "")
  attr(:uri, URI, required: true)

  def search_form(assigns) do
    ~H"""
    <.filter_bar filter_text={@filter_text} placeholder="Search Sites"></.filter_bar>
    """
  end

  def favicon(assigns) do
    src = "/favicon/sources/#{assigns.domain}"
    assigns = assign(assigns, :src, src)

    ~H"""
    <img src={@src} class="size-[18px] shrink-0" />
    """
  end

  def globe_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
      <path
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        d="M22 12H2M12 22c5.714-5.442 5.714-14.558 0-20M12 22C6.286 16.558 6.286 7.442 12 2"
      />
      <path
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
        d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10Z"
      />
    </svg>
    """
  end

  def handle_event("pin-toggle", %{"domain" => domain}, socket) do
    site = Enum.find(socket.assigns.sites.entries, &(&1.domain == domain))

    if site do
      socket =
        case Sites.toggle_pin(socket.assigns.current_user, site) do
          {:ok, preference} ->
            flash_message =
              if preference.pinned_at do
                "Site pinned"
              else
                "Site unpinned"
              end

            socket
            |> put_live_flash(:success, flash_message)
            |> load_sites()
            |> push_event("js-exec", %{
              to: "#site-card-#{hash_domain(site.domain)}",
              attr: "data-pin-toggled"
            })

          {:error, :too_many_pins} ->
            flash_message =
              "Looks like you've hit the pinned sites limit! " <>
                "Please unpin one of your pinned sites to make room for new pins"

            socket
            |> put_live_flash(:error, flash_message)
            |> push_event("js-exec", %{
              to: "#site-card-#{hash_domain(site.domain)}",
              attr: "data-pin-failed"
            })
        end

      {:noreply, socket}
    else
      Sentry.capture_message("Attempting to toggle pin for invalid domain.",
        extra: %{domain: domain, user: socket.assigns.current_user.id}
      )

      {:noreply, socket}
    end
  end

  def handle_event(
        "filter",
        %{"filter-text" => filter_text},
        %{assigns: %{filter_text: filter_text}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_event("filter", %{"filter-text" => filter_text}, socket) do
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

  on_ee do
    def handle_event("consolidated-view-cta-dismiss", _, socket) do
      :ok =
        Plausible.ConsolidatedView.dismiss_cta(
          socket.assigns.current_user,
          socket.assigns.current_team
        )

      {:noreply, assign(socket, :consolidated_view_cta_dismissed?, true)}
    end

    def handle_event("consolidated-view-cta-restore", _, socket) do
      :ok =
        Plausible.ConsolidatedView.restore_cta(
          socket.assigns.current_user,
          socket.assigns.current_team
        )

      {:noreply, assign(socket, :consolidated_view_cta_dismissed?, false)}
    end
  end

  defp load_sites(%{assigns: assigns} = socket) do
    sites =
      Sites.list_with_invitations(assigns.current_user, assigns.params,
        filter_by_domain: assigns.filter_text,
        team: assigns.current_team
      )

    hourly_stats =
      if connected?(socket) do
        try do
          Plausible.Stats.Clickhouse.last_24h_visitors_hourly_intervals(sites.entries)
        catch
          kind, value ->
            Logger.error(
              "Could not render 24h visitors hourly intervals: #{inspect(kind)} #{inspect(value)}"
            )

            %{}
        end
      else
        %{}
      end

    consolidated_stats =
      if connected?(socket),
        do: load_consolidated_stats(assigns.consolidated_view),
        else: :loading

    invitations = extract_invitations(sites.entries, assigns.current_team)

    assign(
      socket,
      sites: sites,
      invitations: invitations,
      hourly_stats: hourly_stats,
      consolidated_stats: consolidated_stats || Map.get(assigns, :consolidated_stats)
    )
  end

  defp extract_invitations(sites, team) do
    sites
    |> Enum.filter(&(&1.entry_type == "invitation"))
    |> Enum.flat_map(& &1.invitations)
    |> Enum.map(&check_limits(&1, team))
  end

  on_ee do
    defp check_limits(%{role: :owner, site: site} = invitation, team) do
      case ensure_can_take_ownership(site, team) do
        :ok ->
          check_features(invitation, team)

        {:error, :no_plan} ->
          %{invitation: invitation, no_plan: true}

        {:error, {:over_plan_limits, limits}} ->
          limits = PlausibleWeb.TextHelpers.pretty_list(limits)
          %{invitation: invitation, exceeded_limits: limits}
      end
    end
  end

  defp check_limits(invitation, _), do: %{invitation: invitation}

  defdelegate ensure_can_take_ownership(site, team), to: Teams.Invitations

  def check_features(%{role: :owner, site: site} = invitation, team) do
    case check_feature_access(site, team) do
      :ok ->
        %{invitation: invitation}

      {:error, {:missing_features, features}} ->
        feature_names =
          features
          |> Enum.map(& &1.display_name())
          |> PlausibleWeb.TextHelpers.pretty_list()

        %{invitation: invitation, missing_features: feature_names}
    end
  end

  defp check_feature_access(site, new_team) do
    missing_features =
      Teams.Billing.features_usage(nil, [site.id])
      |> Enum.filter(&(&1.check_availability(new_team) != :ok))

    if missing_features == [] do
      :ok
    else
      {:error, {:missing_features, missing_features}}
    end
  end

  defp set_filter_text(socket, filter_text) do
    filter_text = String.trim(filter_text)
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

  defp hash_domain(domain) do
    :sha |> :crypto.hash(domain) |> Base.encode16()
  end

  def no_consolidated_view(overrides \\ []) do
    [
      consolidated_view: nil,
      can_manage_consolidated_view?: false,
      consolidated_stats: nil,
      no_consolidated_view_reason: nil,
      consolidated_view_cta_dismissed?: false
    ]
    |> Keyword.merge(overrides)
  end

  on_ee do
    alias Plausible.ConsolidatedView

    defp consolidated_view_ok_to_display?(team, user) do
      ConsolidatedView.ok_to_display?(team, user)
    end

    defp init_consolidated_view_assigns(_user, nil) do
      # technically this is team not setup, but is also equivalent of having no sites at this moment (can have invitations though), so CTA should not be shown
      no_consolidated_view(no_consolidated_view_reason: :no_sites)
    end

    defp init_consolidated_view_assigns(user, team) do
      case ConsolidatedView.enable(team) do
        {:ok, view} ->
          %{
            consolidated_view: view,
            can_manage_consolidated_view?: ConsolidatedView.can_manage?(user, team),
            consolidated_stats: :loading,
            no_consolidated_view_reason: nil,
            consolidated_view_cta_dismissed?: ConsolidatedView.cta_dismissed?(user, team)
          }

        {:error, reason} ->
          no_consolidated_view(
            no_consolidated_view_reason: reason,
            can_manage_consolidated_view?: ConsolidatedView.can_manage?(user, team),
            consolidated_view_cta_dismissed?: ConsolidatedView.cta_dismissed?(user, team)
          )
      end
    end

    defp load_consolidated_stats(consolidated_view) do
      case Plausible.Stats.ConsolidatedView.safe_overview_24h(consolidated_view) do
        {:ok, stats} -> stats
        {:error, :not_found} -> nil
        {:error, :inaccessible} -> :loading
      end
    end
  else
    defp consolidated_view_ok_to_display?(_team, _user), do: false

    defp init_consolidated_view_assigns(_user, _team),
      do: no_consolidated_view(no_consolidated_view_reason: :unavailable)

    defp load_consolidated_stats(_consolidated_view), do: nil
  end
end
