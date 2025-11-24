defmodule PlausibleWeb.Live.Dashboard do
  @moduledoc """
  LV version of pages breakdown.
  """

  use PlausibleWeb, :live_view

  alias Plausible.Repo
  alias Plausible.Stats.Query
  alias Plausible.Teams

  def mount(%{"domain" => domain} = params, _session, socket) do
    current_user = socket.assigns[:current_user]

    site =
      current_user
      |> Plausible.Sites.get_for_user(domain)
      |> Plausible.Repo.preload(:owners)

    membership_role =
      case Plausible.Teams.Memberships.site_role(site, current_user) do
        {:ok, {_, role}} -> role
        _ -> nil
      end

    shared_link = maybe_get_shared_link(params, site)

    site_role =
      cond do
        membership_role ->
          membership_role

        Plausible.Auth.is_super_admin?(current_user) ->
          :super_admin

        site.public ->
          :public

        shared_link ->
          :public

        true ->
          nil
      end

    stats_start_date = Plausible.Sites.stats_start_date(site)
    can_see_stats? = not Teams.locked?(site.team) or site_role == :super_admin
    demo = site.domain == "plausible.io"
    dogfood_page_path = if demo, do: "/#{site.domain}", else: "/:dashboard"

    consolidated_view? = Plausible.Sites.consolidated?(site)

    consolidated_view_available? =
      on_ee(do: Plausible.ConsolidatedView.ok_to_display?(site.team), else: false)

    team_identifier = site.team.identifier

    skip_to_dashboard? =
      params["skip_to_dashboard"] == "true" or consolidated_view?

    {:ok, segments} = Plausible.Segments.get_all_for_site(site, site_role)

    cond do
      consolidated_view? and not consolidated_view_available? and site_role != :super_admin ->
        {:ok, redirect(socket, to: Routes.site_path(socket, :index))}

      (stats_start_date && can_see_stats?) || (can_see_stats? && skip_to_dashboard?) ->
        flags = get_flags(current_user, site)

        {:ok,
         assign(
           socket,
           site: site,
           site_role: site_role,
           has_goals: Plausible.Sites.has_goals?(site),
           revenue_goals: list_revenue_goals(site),
           funnels: list_funnels(site),
           has_props: Plausible.Props.configured?(site),
           stats_start_date: stats_start_date,
           native_stats_start_date: NaiveDateTime.to_date(site.native_stats_start_at),
           title: dashboard_title(site),
           demo: demo,
           flags: flags,
           is_dbip: is_dbip(),
           segments: segments,
           load_dashboard_js: true,
           hide_footer?: if(ce?() || demo, do: false, else: site_role != :public),
           consolidated_view?: consolidated_view?,
           consolidated_view_available?: consolidated_view_available?,
           team_identifier: team_identifier,
           dogfood_page_path: dogfood_page_path,
           locked?: false,
           width_param: params["width"],
           params: params
         )}

      !stats_start_date && can_see_stats? ->
        {:ok, redirect(socket, to: Routes.site_path(socket, :verification, site.domain))}

      Teams.locked?(site.team) ->
        site = Plausible.Repo.preload(site, :owners)
        {:ok, assign(socket, locked?: true, site: site, dogfood_page_path: dogfood_page_path)}
    end
  end

  def handle_params(params, url, socket) do
    uri = URI.parse(url)

    filters =
      (uri.query || "")
      |> String.split("&")
      |> Enum.map(&parse_filter/1)
      |> Enum.filter(&Function.identity/1)
      |> Jason.encode!()

    params = Map.put(params, "filters", filters)

    query = Query.from(socket.assigns.site, params, %{})

    socket = assign(socket, :query, query)

    {:noreply, socket}
  end

  defp parse_filter("f=" <> filter_expr) do
    case String.split(filter_expr, ",") do
      ["is", metric, value] when metric in ["page"] ->
        [:is, "event:#{metric}", [value]]

      ["is", metric, value] ->
        [:is, "visit:#{metric}", [value]]

      _ ->
        nil
    end
  end

  defp parse_filter(_), do: nil

  def render(assigns) do
    ~H"""
    <div class={stats_container_class(!!assigns[:embedded], @width_param)} data-site-domain={@site.domain}>
    <PlausibleWeb.Components.FirstDashboardLaunchBanner.render site={@site} />

    <div
      :if={Plausible.Teams.locked?(@site.team)}
      class="w-full px-4 py-4 text-sm font-bold text-center text-yellow-800 bg-yellow-100 rounded-sm transition"
      style="top: 91px"
      role="alert"
    >
      <p>This dashboard is actually locked. You are viewing it with super-admin access</p>
    </div>

    <div class="pt-6"></div>
    <div
    id="stats-react-container"
    phx-update="ignore"
    style="overflow-anchor: none;"
    data-domain={@site.domain}
    data-offset={Plausible.Site.tz_offset(@site)}
    data-has-goals={to_string(@has_goals)}
    data-conversions-opted-out={to_string(Plausible.Billing.Feature.Goals.opted_out?(@site))}
    data-funnels-opted-out={to_string(Plausible.Billing.Feature.Funnels.opted_out?(@site))}
    data-props-opted-out={to_string(Plausible.Billing.Feature.Props.opted_out?(@site))}
    data-funnels-available={
      to_string(Plausible.Billing.Feature.Funnels.check_availability(@site.team) == :ok)
    }
    data-props-available={
      to_string(Plausible.Billing.Feature.Props.check_availability(@site.team) == :ok)
    }
    data-site-segments-available={
      to_string(Plausible.Billing.Feature.SiteSegments.check_availability(@site.team) == :ok)
    }
    data-revenue-goals={Jason.encode!(@revenue_goals)}
    data-funnels={Jason.encode!(@funnels)}
    data-has-props={to_string(@has_props)}
    data-logged-in={to_string(!!assigns[:current_user])}
    data-stats-begin={@stats_start_date}
    data-native-stats-begin={@native_stats_start_date}
    data-shared-link-auth={assigns[:shared_link_auth]}
    data-embedded={to_string(assigns[:embedded])}
    data-background={assigns[:background]}
    data-is-dbip={to_string(@is_dbip)}
    data-current-user-role={@site_role}
    data-current-user-id={
      if user = assigns[:current_user], do: user.id, else: Jason.encode!(nil)
    }
    data-flags={Jason.encode!(@flags)}
    data-segments={Jason.encode!(@segments)}
    data-valid-intervals-by-period={
      Plausible.Stats.Interval.valid_by_period(site: @site) |> Jason.encode!()
    }
    data-is-consolidated-view={Jason.encode!(@consolidated_view?)}
    data-consolidated-view-available={Jason.encode!(@consolidated_view_available?)}
    data-team-identifier={@team_identifier}
    >
    </div>
    <div id="pages-breakdown-live2"></div>
    <div id="live-dashbaord-container">
      <.portal id="pages-breakdown-live-container" target="#pages-breakdown-live">
        <.live_component 
          module={PlausibleWeb.Live.Dashboard.Pages}
          id="pages-breakdown-component"
          params={@params}
          site={@site}
          query={@query}
        >
        </.live_component>
      </.portal>
    </div>
        <div id="modal_root"></div>
    <div :if={!assigns[:current_user] && assigns[:demo]} class="bg-gray-50 dark:bg-gray-850">
      <div class="py-12 lg:py-16 lg:flex lg:items-center lg:justify-between">
        <h2 class="text-3xl font-extrabold tracking-tight text-gray-900 leading-9 sm:text-4xl sm:leading-10 dark:text-gray-100">
          Want these stats for your website? <br />
          <span class="text-indigo-600">Start your free trial today.</span>
        </h2>
        <div class="flex mt-8 lg:shrink-0 lg:mt-0">
          <div class="inline-flex shadow-sm rounded-md">
            <a
              href="/register"
              class="inline-flex items-center justify-center px-5 py-3 text-base font-medium text-white bg-indigo-600 border border-transparent leading-6 rounded-md hover:bg-indigo-500 focus:outline-hidden focus:ring transition duration-150 ease-in-out"
            >
              Get started
            </a>
          </div>
          <div class="inline-flex ml-3 shadow-xs rounded-md">
            <a
              href="/"
              class="inline-flex items-center justify-center px-5 py-3 text-base font-medium text-indigo-600 bg-white border border-transparent leading-6 rounded-md dark:text-gray-100 dark:bg-gray-800 hover:text-indigo-500 dark:hover:text-indigo-500 focus:outline-hidden focus:ring transition duration-150 ease-in-out"
            >
              Learn more
            </a>
          </div>
        </div>
      </div>
    </div>
    </div>
    """
  end

  def handle_event("handle_dashboard_params", %{"url" => url}, socket) do
    params = 
      url
      |> URI.parse()
      |> Map.fetch!(:query)
      |> URI.decode_query()

    handle_params(params, url, socket)
  end

  on_ee do
    defp list_funnels(site) do
      Plausible.Funnels.list(site)
    end

    defp list_revenue_goals(site) do
      Plausible.Goals.list_revenue_goals(site)
    end
  else
    defp list_funnels(_site), do: []
    defp list_revenue_goals(_site), do: []
  end

  defp get_flags(user, site),
    do:
      []
      |> Enum.map(fn flag ->
        {flag, FunWithFlags.enabled?(flag, for: user) || FunWithFlags.enabled?(flag, for: site)}
      end)
      |> Map.new()

  defp is_dbip() do
    on_ee do
      false
    else
      Plausible.Geo.database_type()
      |> to_string()
      |> String.starts_with?("DBIP")
    end
  end

  defp dashboard_title(site) do
    "Plausible · " <> site.domain
  end

  def stats_container_class(embedded?, width_param) do
    cond do
      embedded? and width_param == "manual" -> "px-6"
      embedded? -> "max-w-screen-xl mx-auto px-6"
      true -> "container print:max-w-full"
    end
  end

  defp maybe_get_shared_link(params, site) do
    slug = params["slug"] || params["auth"]

    if valid_path_fragment?(slug) do
      if shared_link = Repo.get_by(Plausible.Site.SharedLink, slug: slug, site_id: site.id) do
        shared_link
      else
        nil
      end
    else
      nil
    end
  end

  defp valid_path_fragment?(fragment), do: is_binary(fragment) and String.valid?(fragment)
end
