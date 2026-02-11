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
      |> assign(:sparklines, %{})
      |> assign(:filter_text, String.trim(params["filter_text"] || ""))
      |> assign(init_consolidated_view_assigns(user, team))
      |> assign(:team_invitations, [])
      |> assign(:site_invitations, [])
      |> assign(:site_ownership_invitations, [])

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:params, params)
      |> load_sites()
      |> load_invitations()
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
      |> then(fn socket ->
        %{
          sites: sites,
          current_team: current_team,
          has_sites?: has_sites?,
          filter_text: filter_text
        } = socket.assigns

        is_empty_state? =
          not (sites.entries != [] and (Teams.setup?(current_team) or has_sites?)) and
            filter_text == ""

        empty_state_title =
          if Teams.setup?(current_team) do
            "Add your first team site"
          else
            "Add your first personal site"
          end

        empty_state_description =
          "Collect simple, privacy-friendly stats to better understand your audience."

        assign(socket,
          is_empty_state?: is_empty_state?,
          empty_state_title: empty_state_title,
          empty_state_description: empty_state_description
        )
      end)

    {:noreply, socket}
  end

  def render(assigns) do
    assigns = assign(assigns, :searching?, String.trim(assigns.filter_text) != "")

    ~H"""
    <.flash_messages flash={@flash} />
    <div class="container pt-6">
      <PlausibleWeb.Live.Components.Visitors.gradient_defs />
      <.upgrade_nag_screen :if={
        @needs_to_upgrade == {:needs_to_upgrade, :no_active_trial_or_subscription}
      } />

      <div class="group mt-6 pb-5 border-b border-gray-200 dark:border-gray-750 flex items-center gap-2">
        <h2 class="text-xl font-bold leading-7 text-gray-900 dark:text-gray-100 sm:text-2xl md:text-3xl sm:leading-9 min-w-0 truncate">
          {Teams.name(@current_team)}
        </h2>
        <.unstyled_link
          :if={Teams.setup?(@current_team)}
          data-test-id="team-settings-link"
          href={Routes.settings_path(@socket, :team_general)}
          class="shrink-0"
        >
          <Heroicons.cog_6_tooth class="hidden group-hover:inline size-5 dark:text-gray-100 text-gray-900" />
        </.unstyled_link>
      </div>

      <div
        :if={not @is_empty_state?}
        class="relative z-10 pt-4 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-y-2"
      >
        <.search_form filter_text={@filter_text} uri={@uri} />
        <PrimaDropdown.dropdown
          :if={@consolidated_view_cta_dismissed?}
          id="add-site-dropdown"
        >
          <PrimaDropdown.dropdown_trigger as={&button/1} id="add-site-dropdown-trigger" mt?={false}>
            <Heroicons.plus class="size-4" /> Add
            <Heroicons.chevron_down mini class="size-4 mt-0.5" />
          </PrimaDropdown.dropdown_trigger>

          <PrimaDropdown.dropdown_menu id="add-site-dropdown-menu">
            <PrimaDropdown.dropdown_item
              as={&link/1}
              id="add-site-dropdown-menuitem-1"
              href={Routes.site_path(@socket, :new, %{flow: PlausibleWeb.Flows.provisioning()})}
            >
              <Heroicons.plus class={PrimaDropdown.dropdown_item_icon_class()} /> Add website
            </PrimaDropdown.dropdown_item>
            <PrimaDropdown.dropdown_item
              id="add-site-dropdown-menuitem-2"
              phx-click="consolidated-view-cta-restore"
            >
              <Heroicons.plus class={PrimaDropdown.dropdown_item_icon_class()} />
              Add consolidated view
            </PrimaDropdown.dropdown_item>
          </PrimaDropdown.dropdown_menu>
        </PrimaDropdown.dropdown>

        <a
          :if={!@consolidated_view_cta_dismissed?}
          href={"/sites/new?flow=#{PlausibleWeb.Flows.provisioning()}"}
          class="whitespace-nowrap truncate inline-flex items-center justify-center gap-x-2 max-w-fit font-medium rounded-md px-3.5 py-2.5 text-sm cursor-pointer disabled:cursor-not-allowed bg-indigo-600 text-white hover:bg-indigo-700 focus-visible:outline-indigo-600 disabled:bg-indigo-400/60 disabled:dark:bg-indigo-600/30 disabled:dark:text-white/35"
        >
          <Heroicons.plus class="size-4" /> Add website
        </a>
      </div>

      <div class="flex flex-col gap-y-4 my-4">
        <PlausibleWeb.Team.Notice.team_invitations team_invitations={@team_invitations} />
        <PlausibleWeb.Team.Notice.site_ownership_invitations
          site_ownership_invitations={@site_ownership_invitations}
          current_team={@current_team}
        />
        <PlausibleWeb.Team.Notice.site_invitations site_invitations={@site_invitations} />
      </div>

      <p :if={@searching? and @sites.entries == []} class="mt-4 dark:text-gray-100 text-center">
        No sites found. Try a different search term.
      </p>
      <div
        :if={@is_empty_state?}
        class="flex flex-col items-center justify-center py-8 sm:py-12 max-w-md mx-auto"
      >
        <h3 class="text-center text-base font-medium text-gray-900 dark:text-gray-100 leading-7">
          {@empty_state_title}
        </h3>
        <p class="text-center text-sm mt-1 text-gray-500 dark:text-gray-400 leading-5 text-pretty">
          {@empty_state_description}
        </p>
        <div class="flex flex-col sm:flex-row gap-3 mt-6">
          <.button_link
            href={"/sites/new?flow=#{PlausibleWeb.Flows.provisioning()}"}
            theme="primary"
            mt?={false}
          >
            <Heroicons.plus class="size-4" /> Add website
          </.button_link>
          <.button_link
            :if={not Teams.setup?(@current_team) and @has_sites?}
            href={Routes.auth_path(@socket, :select_team)}
            theme="secondary"
            mt?={false}
          >
            Go to team sites
          </.button_link>
        </div>
      </div>

      <div :if={@has_sites?}>
        <ul class="my-6 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <.consolidated_view_card_cta
            :if={
              not @searching? and
                !@consolidated_view and @no_consolidated_view_reason not in [:no_sites, :unavailable] and
                not @consolidated_view_cta_dismissed?
            }
            can_manage_consolidated_view?={@can_manage_consolidated_view?}
            no_consolidated_view_reason={@no_consolidated_view_reason}
            current_user={@current_user}
            current_team={@current_team}
          />
          <.consolidated_view_card
            :if={
              not @searching? and not is_nil(@consolidated_view) and
                consolidated_view_ok_to_display?(@current_team)
            }
            can_manage_consolidated_view?={@can_manage_consolidated_view?}
            consolidated_view={@consolidated_view}
            consolidated_sparkline={@consolidated_sparkline}
            current_user={@current_user}
            current_team={@current_team}
          />
          <%= for site <- @sites.entries do %>
            <.site
              site={site}
              sparkline={Map.get(@sparklines, site.domain, :loading)}
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
        <p class="text-xs sm:text-sm text-gray-600 dark:text-gray-400">
          Introducing
        </p>
        <h3 class="text-lg sm:text-[1.35rem] font-bold text-gray-900 leading-tighter dark:text-gray-100">
          Consolidated view
        </h3>
      </div>

      <div
        :if={@no_consolidated_view_reason == :team_not_setup}
        class="flex flex-col gap-y-4"
      >
        <p class="text-sm sm:text-base text-gray-900 dark:text-gray-100 leading-tighter">
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
          class="text-sm sm:text-base text-gray-900 dark:text-gray-100 leading-tighter"
        >
          Upgrade to the Business plan<span :if={not Teams.setup?(@current_team)}> and set up a team</span> to enable consolidated view.
        </p>

        <p
          :if={not @can_manage_consolidated_view?}
          class="text-sm sm:text-base text-gray-900 dark:text-gray-100 leading-tighter"
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

      <div
        :if={@no_consolidated_view_reason == :contact_us}
        class="flex flex-col gap-y-4"
      >
        <p class="text-sm sm:text-base text-gray-900 dark:text-gray-100 leading-tighter">
          Your plan does not include consolidated view. Contact us to discuss an upgrade.
        </p>

        <div class="flex gap-x-2">
          <.button_link
            href="mailto:hello@plausible.io"
            mt?={false}
          >
            Contact us
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
      class="relative row-span-2"
    >
      <.unstyled_link
        href={"/#{URI.encode_www_form(@consolidated_view.domain)}"}
        class="flex flex-col justify-between gap-6 h-full bg-white p-6 dark:bg-gray-900 rounded-md shadow-sm cursor-pointer hover:shadow-lg transition-shadow duration-150"
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
            :if={is_map(@consolidated_sparkline)}
            class="max-w-sm sm:max-w-none text-indigo-500 my-auto"
            data-test-id="consolidated-view-chart-loaded"
          >
            <PlausibleWeb.Live.Components.Visitors.chart
              intervals={@consolidated_sparkline.intervals}
              height={80}
            />
          </span>
        </div>
        <div
          :if={is_map(@consolidated_sparkline)}
          data-test-id="consolidated-view-stats-loaded"
          class="flex flex-col flex-1 justify-between gap-y-2.5 sm:gap-y-5"
        >
          <div class="flex flex-col sm:flex-row justify-between gap-2.5 sm:gap-2 flex-1 w-full">
            <.consolidated_view_stat
              value={large_number_format(@consolidated_sparkline.visitors)}
              label="Unique visitors"
              change={@consolidated_sparkline.visitors_change}
            />
            <.consolidated_view_stat
              value={large_number_format(@consolidated_sparkline.visits)}
              label="Total visits"
              change={@consolidated_sparkline.visits_change}
            />
          </div>
          <div class="flex flex-col sm:flex-row justify-between gap-2.5 sm:gap-2 flex-1 w-full">
            <.consolidated_view_stat
              value={large_number_format(@consolidated_sparkline.pageviews)}
              label="Total pageviews"
              change={@consolidated_sparkline.pageviews_change}
            />
            <.consolidated_view_stat
              value={@consolidated_sparkline.views_per_visit}
              label="Views per visit"
              change={@consolidated_sparkline.views_per_visit_change}
            />
          </div>
        </div>
        <div
          :if={@consolidated_sparkline == :loading}
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
  attr(:sparkline, :map, required: true)

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
      <.unstyled_link href={"/#{URI.encode_www_form(@site.domain)}"} class="block">
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
          <.site_stats sparkline={@sparkline} />
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
          <Heroicons.cog_6_tooth class="size-5 text-gray-600 dark:text-gray-400 group-hover/item:text-gray-900 dark:group-hover/item:text-gray-100" />
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
            class="size-[1.15rem] text-indigo-600 dark:text-indigo-500 group-hover/item:text-indigo-700 dark:group-hover/item:text-indigo-400"
          />
          <span :if={@site.pinned_at}>Unpin site</span>

          <.icon_pin
            :if={!@site.pinned_at}
            class="size-5 text-gray-600 dark:text-gray-400 group-hover/item:text-gray-900 dark:group-hover/item:text-gray-100"
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

  attr(:sparkline, :any, required: true)

  def site_stats(assigns) do
    ~H"""
    <div class={[
      "flex flex-col gap-y-2 h-[122px] text-center animate-pulse",
      is_map(@sparkline) && " hidden"
    ]}>
      <div class="flex-2 dark:bg-gray-750 bg-gray-100 rounded-md"></div>
      <div class="flex-1 dark:bg-gray-750 bg-gray-100 rounded-md"></div>
    </div>
    <div :if={is_map(@sparkline)}>
      <span class="flex flex-col gap-y-5 text-gray-600 dark:text-gray-400 text-sm truncate">
        <span class="max-w-sm sm:max-w-none text-indigo-500">
          <PlausibleWeb.Live.Components.Visitors.chart
            intervals={@sparkline.intervals}
            height={80}
          />
        </span>
        <div class="flex justify-between items-end">
          <div class="flex flex-col">
            <p class="text-lg sm:text-xl font-bold text-gray-900 dark:text-gray-100">
              {large_number_format(@sparkline.visitors)}
            </p>
            <p class="text-gray-600 dark:text-gray-400">
              visitor<span :if={@sparkline.visitors != 1}>s</span> in last 24h
            </p>
          </div>

          <.percentage_change change={@sparkline.visitors_change} />
        </div>
      </span>
    </div>
    """
  end

  attr(:change, :integer, required: true)

  # Related React component: <ChangeArrow />
  def percentage_change(assigns) do
    ~H"""
    <p class="text-sm text-gray-900 dark:text-gray-100">
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

  defp load_invitations(%{assigns: %{params: %{"page" => page}}} = socket) when page != "1" do
    socket
  end

  defp load_invitations(%{assigns: %{current_user: user, current_team: team}} = socket) do
    site_transfers =
      user
      |> Teams.Invitations.pending_site_transfers_for()
      |> Enum.map(&Map.put(&1, :ownership_check, ensure_can_take_ownership(&1.site, team)))

    socket
    |> assign(:team_invitations, Teams.Invitations.pending_team_invitations_for(user))
    |> assign(:site_invitations, Teams.Invitations.pending_guest_invitations_for(user))
    |> assign(:site_ownership_invitations, site_transfers)
  end

  defp load_sites(%{assigns: assigns} = socket) do
    sites =
      Sites.list(assigns.current_user, assigns.params,
        filter_by_domain: assigns.filter_text,
        team: assigns.current_team
      )

    sparklines =
      if connected?(socket) do
        Plausible.Stats.Sparkline.parallel_overview(sites.entries)
      else
        %{}
      end

    consolidated_sparkline =
      if connected?(socket),
        do: load_consolidated_sparkline(assigns.consolidated_view),
        else: :loading

    assign(
      socket,
      sites: sites,
      sparklines: sparklines,
      consolidated_sparkline: consolidated_sparkline || Map.get(assigns, :consolidated_sparkline)
    )
  end

  on_ee do
    defdelegate ensure_can_take_ownership(site, team), to: Teams.Invitations
  else
    defp ensure_can_take_ownership(_site, _team), do: :ok
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
      consolidated_sparkline: nil,
      no_consolidated_view_reason: nil,
      consolidated_view_cta_dismissed?: false
    ]
    |> Keyword.merge(overrides)
  end

  on_ee do
    alias Plausible.ConsolidatedView

    defp consolidated_view_ok_to_display?(team) do
      ConsolidatedView.ok_to_display?(team)
    end

    defp init_consolidated_view_assigns(_user, nil) do
      # technically this is team not setup, but is also equivalent of having no sites at this moment, so CTA should not be shown
      no_consolidated_view(no_consolidated_view_reason: :no_sites)
    end

    defp init_consolidated_view_assigns(user, team) do
      case ConsolidatedView.enable(team) do
        {:ok, view} ->
          %{
            consolidated_view: view,
            can_manage_consolidated_view?: ConsolidatedView.can_manage?(user, team),
            consolidated_sparkline: :loading,
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

    defp load_consolidated_sparkline(consolidated_view) do
      case Plausible.Stats.Sparkline.safe_overview_24h(consolidated_view) do
        {:ok, stats} -> stats
        {:error, :not_found} -> nil
        {:error, :inaccessible} -> :loading
      end
    end
  else
    defp consolidated_view_ok_to_display?(_team), do: false

    defp init_consolidated_view_assigns(_user, _team),
      do: no_consolidated_view(no_consolidated_view_reason: :unavailable)

    defp load_consolidated_sparkline(_consolidated_view), do: nil
  end
end
