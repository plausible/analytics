defmodule PlausibleWeb.Api.StatsController do
  use Plausible
  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler

  alias Plausible.Stats

  alias Plausible.Stats.{
    Query,
    Comparisons,
    Filters,
    TableDecider,
    Dashboard,
    ParsedQueryParams,
    QueryBuilder,
    QueryError
  }

  alias PlausibleWeb.Api.Helpers, as: H

  require Logger

  @revenue_metrics on_ee(do: Plausible.Stats.Goal.Revenue.revenue_metrics(), else: [])
  @not_set "(not set)"

  on_ee do
    plug PlausibleWeb.SuperAdminOnlyPlug
         when action in [
                :exploration_next,
                :exploration_funnel,
                :exploration_next_with_funnel,
                :exploration_interesting_funnel
              ]
  end

  plug(:date_validation_plug when action not in [:query])
  plug(:validate_required_filters_plug when action not in [:current_visitors])

  def query(conn, params) do
    site = conn.assigns.site
    now = conn.private[:now]

    with {:ok, %ParsedQueryParams{} = params} <- Dashboard.QueryParser.parse(params, now: now),
         {:ok, %Query{} = query} <- QueryBuilder.build(site, params, debug_metadata(conn)) do
      query =
        if query.include.time_labels do
          Query.set_include(query, :time_label_result_indices, true)
        else
          query
        end

      json(conn, Plausible.Stats.query(site, query))
    else
      {:error, %QueryError{message: message}} -> bad_request(conn, message)
    end
  end

  def sources(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:source")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    extra_metrics =
      if params["detailed"],
        do: [:percentage, :bounce_rate, :visit_duration],
        else: [:percentage]

    metrics =
      breakdown_metrics(query,
        extra_metrics: extra_metrics,
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    res =
      results
      |> transform_keys(%{source: :name})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, %{
        results: res,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def channels(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:channel")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    extra_metrics =
      if params["detailed"],
        do: [:percentage, :bounce_rate, :visit_duration],
        else: [:percentage]

    metrics =
      breakdown_metrics(query,
        extra_metrics: extra_metrics,
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    res =
      results
      |> transform_keys(%{channel: :name})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, %{
        results: res,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  on_ee do
    @exploration_wildcard_disabled_flag :exploration_wildcard_disabled

    def exploration_next(conn, %{"journey" => steps} = params) do
      site = conn.assigns.site
      search_term = params["search_term"] || ""

      with {:ok, journey} <- parse_journey(steps),
           {:ok, direction} <- parse_exploration_direction(params["direction"]),
           query = Query.from(site, params, debug_metadata: debug_metadata(conn)),
           include_wildcard? =
             not FunWithFlags.enabled?(@exploration_wildcard_disabled_flag, for: site),
           {:ok, next_steps} <-
             Plausible.Stats.Exploration.next_steps(query, journey,
               search_term: search_term,
               direction: direction,
               include_wildcard?: include_wildcard?
             ) do
        json(conn, next_steps)
      else
        {:error, :journey_too_long} ->
          bad_request(conn, "The journey is too long")
      end
    end

    def exploration_funnel(conn, %{"journey" => steps} = params) do
      site = conn.assigns.site

      with {:ok, journey} <- parse_journey(steps),
           {:ok, direction} <- parse_exploration_direction(params["direction"]),
           query = Query.from(site, params, debug_metadata: debug_metadata(conn)),
           {:ok, funnel} <-
             Plausible.Stats.Exploration.journey_funnel(query, journey, direction) do
        json(conn, funnel)
      else
        {:error, :empty_journey} ->
          bad_request(conn, "We are unable to show funnels when journey is empty")

        {:error, :journey_too_long} ->
          bad_request(conn, "The journey is too long")
      end
    end

    def exploration_interesting_funnel(conn, params) do
      site = conn.assigns.site
      query = Query.from(site, params, debug_metadata: debug_metadata(conn))

      include_wildcard? =
        not FunWithFlags.enabled?(@exploration_wildcard_disabled_flag, for: site)

      case Plausible.Stats.Exploration.interesting_funnel(query,
             max_steps: params["max_steps"],
             max_candidates: params["max_candidates"],
             include_wildcard?: include_wildcard?
           ) do
        {:ok, funnel} -> json(conn, funnel)
        {:error, :not_found} -> json(conn, [])
      end
    end

    def exploration_next_with_funnel(conn, %{"journey" => steps} = params) do
      site = conn.assigns.site
      search_term = params["search_term"] || ""
      include_funnel? = params["include_funnel"] == true

      with {:ok, journey} <- parse_journey(steps),
           {:ok, direction} <- parse_exploration_direction(params["direction"]),
           query = Query.from(site, params, debug_metadata: debug_metadata(conn)),
           include_wildcard? =
             not FunWithFlags.enabled?(@exploration_wildcard_disabled_flag, for: site),
           {:ok, next_steps} <-
             Plausible.Stats.Exploration.next_steps(query, journey,
               search_term: search_term,
               direction: direction,
               include_wildcard?: include_wildcard?
             ),
           funnel <- maybe_include_funnel(include_funnel?, query, journey, direction) do
        json(conn, %{next: next_steps, funnel: funnel})
      else
        _ ->
          bad_request(conn, "There was an error with your request")
      end
    end

    defp maybe_include_funnel(true, query, journey, direction) do
      case Plausible.Stats.Exploration.journey_funnel(query, journey, direction) do
        {:ok, funnel_data} -> funnel_data
        {:error, :empty_journey} -> []
      end
    end

    defp maybe_include_funnel(false, _, _, _), do: []

    defp parse_journey(input) when is_binary(input) do
      input
      |> Jason.decode!()
      |> Enum.map(&parse_journey_step/1)
      |> then(&{:ok, &1})
    end

    defp parse_journey_step(%{
           "name" => name,
           "pathname" => pathname,
           "includes_subpaths" => includes_subpaths,
           "subpaths_count" => subpaths_count
         }) do
      Plausible.Stats.Exploration.Journey.Step.new(
        name,
        pathname,
        includes_subpaths,
        subpaths_count
      )
    end

    defp parse_exploration_direction("backward"), do: {:ok, :backward}
    defp parse_exploration_direction("forward"), do: {:ok, :forward}
    defp parse_exploration_direction(_), do: {:ok, :forward}
  end

  on_ee do
    def funnel(conn, %{"id" => funnel_id} = params) do
      site = Plausible.Repo.preload(conn.assigns.site, :team)

      with :ok <- Plausible.Billing.Feature.Funnels.check_availability(site.team),
           query <- Query.from(site, params, debug_metadata: debug_metadata(conn)),
           :ok <- validate_funnel_query(query),
           {funnel_id, ""} <- Integer.parse(funnel_id),
           {:ok, funnel} <- Stats.funnel(site, query, funnel_id) do
        json(conn, funnel)
      else
        {:error, {:invalid_funnel_query, due_to}} ->
          bad_request(
            conn,
            "We are unable to show funnels when the dashboard is filtered by #{due_to}",
            %{
              level: :normal
            }
          )

        {:error, :funnel_not_found} ->
          conn
          |> put_status(404)
          |> json(%{error: "Funnel not found"})
          |> halt()

        {:error, :upgrade_required} ->
          H.payment_required(
            conn,
            "#{Plausible.Billing.Feature.Funnels.display_name()} is part of the Plausible Business plan. To get access to this feature, please upgrade your account."
          )

        _ ->
          bad_request(conn, "There was an error with your request")
      end
    end

    defp validate_funnel_query(query) do
      cond do
        toplevel_goal_filter?(query) ->
          {:error, {:invalid_funnel_query, "goals"}}

        Filters.filtering_on_dimension?(query, "event:page") ->
          {:error, {:invalid_funnel_query, "pages"}}

        query.input_date_range == :realtime ->
          {:error, {:invalid_funnel_query, "realtime period"}}

        true ->
          :ok
      end
    end
  end

  def utm_mediums(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:utm_medium")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    metrics =
      breakdown_metrics(query,
        extra_metrics: [:percentage, :bounce_rate, :visit_duration],
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    res =
      results
      |> transform_keys(%{utm_medium: :name})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, %{
        results: res,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def utm_campaigns(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:utm_campaign")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    metrics =
      breakdown_metrics(query,
        extra_metrics: [:percentage, :bounce_rate, :visit_duration],
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    res =
      results
      |> transform_keys(%{utm_campaign: :name})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, %{
        results: res,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def utm_contents(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:utm_content")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    metrics =
      breakdown_metrics(query,
        extra_metrics: [:percentage, :bounce_rate, :visit_duration],
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    res =
      results
      |> transform_keys(%{utm_content: :name})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, %{
        results: res,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def utm_terms(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:utm_term")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    metrics =
      breakdown_metrics(query,
        extra_metrics: [:percentage, :bounce_rate, :visit_duration],
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    res =
      results
      |> transform_keys(%{utm_term: :name})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, %{
        results: res,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def utm_sources(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:utm_source")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    metrics =
      breakdown_metrics(query,
        extra_metrics: [:percentage, :bounce_rate, :visit_duration],
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    res =
      results
      |> transform_keys(%{utm_source: :name})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, %{
        results: res,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def referrers(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:referrer")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    metrics =
      breakdown_metrics(query,
        extra_metrics: [:percentage, :bounce_rate, :visit_duration],
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    res =
      results
      |> transform_keys(%{referrer: :name})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        res
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        res |> to_csv([:name, :visitors, :bounce_rate, :visit_duration])
      end
    else
      json(conn, %{
        results: res,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def referrer_drilldown(conn, %{"referrer" => "Google"} = params) do
    site = conn.assigns[:site]

    query = Query.from(site, params, debug_metadata: debug_metadata(conn))

    is_admin =
      if current_user = conn.assigns[:current_user] do
        Plausible.Teams.Memberships.has_editor_access?(site, current_user)
      else
        false
      end

    pagination = {
      to_int(params["limit"], 9),
      to_int(params["page"], 0)
    }

    search = params["search"] || ""

    not_configured_error_payload = %{error_code: :not_configured, is_admin: is_admin}

    search_terms = google_api().fetch_stats(site, query, pagination, search)
    period_too_recent? = DateTime.diff(query.now, query.utc_time_range.first, :hour) < 72

    case {search_terms, period_too_recent?} do
      {{:error, :google_property_not_configured}, _} ->
        conn
        |> put_status(422)
        |> json(not_configured_error_payload)

      {{:error, :unsupported_filters}, _} ->
        conn
        |> put_status(422)
        |> json(%{error_code: :unsupported_filters})

      {{:ok, []}, _period_too_recent? = true} ->
        # We consider this an error case because Google Search Console
        # data is usually delayed 1-3 days.
        conn
        |> put_status(422)
        |> json(%{error_code: :period_too_recent})

      {{:ok, terms}, _} ->
        json(conn, %{results: terms})

      {{:error, error}, _} ->
        Logger.error("Plausible.Google.API.fetch_stats failed with error: `#{inspect(error)}`")

        conn
        |> put_status(502)
        |> json(not_configured_error_payload)
    end
  end

  def referrer_drilldown(conn, %{"referrer" => referrer} = params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:referrer")

    query =
      Query.from(site, params, debug_metadata: debug_metadata(conn))
      |> Query.add_filter([:is, "visit:source", [referrer]])

    pagination = parse_pagination(params)

    extra_metrics =
      if params["detailed"],
        do: [:percentage, :bounce_rate, :visit_duration],
        else: [:percentage]

    metrics =
      breakdown_metrics(query,
        extra_metrics: extra_metrics,
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    referrers =
      results
      |> transform_keys(%{referrer: :name})

    json(conn, %{
      results: referrers,
      meta: Stats.Breakdown.formatted_date_ranges(query),
      skip_imported_reason: meta[:imports_skip_reason]
    })
  end

  def pages(conn, params) do
    site = conn.assigns[:site]

    params = Map.put(params, "property", "event:page")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))

    extra_metrics =
      if params["detailed"] do
        [:percentage, :pageviews, :bounce_rate, :time_on_page, :scroll_depth]
      else
        [:percentage]
      end

    metrics =
      breakdown_metrics(query,
        extra_metrics: extra_metrics,
        include_revenue?: !!params["detailed"]
      )

    pagination = parse_pagination(params)

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    pages =
      results
      |> transform_keys(%{page: :name})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        pages
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        cols = [:name, :visitors, :pageviews, :bounce_rate, :time_on_page, :scroll_depth]
        pages |> to_csv(cols)
      end
    else
      json(conn, %{
        results: pages,
        meta: Map.new(meta.values) |> Map.merge(Stats.Breakdown.formatted_date_ranges(query)),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def entry_pages(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:entry_page")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    metrics =
      breakdown_metrics(query,
        extra_metrics: [:percentage, :visits, :visit_duration, :bounce_rate],
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    entry_pages =
      results
      |> transform_keys(%{entry_page: :name})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        to_csv(entry_pages, [:name, :visitors, :conversion_rate], [
          :name,
          :conversions,
          :conversion_rate
        ])
      else
        to_csv(entry_pages, [:name, :visitors, :visits, :bounce_rate, :visit_duration], [
          :name,
          :unique_entrances,
          :total_entrances,
          :bounce_rate,
          :visit_duration
        ])
      end
    else
      json(conn, %{
        results: entry_pages,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def exit_pages(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:exit_page")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    {limit, page} = parse_pagination(params)

    extra_metrics =
      if TableDecider.sessions_join_events?(query) do
        [:percentage, :visits]
      else
        [:percentage, :visits, :exit_rate]
      end

    metrics =
      breakdown_metrics(query,
        extra_metrics: extra_metrics,
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, {limit, page})

    exit_pages =
      results
      |> transform_keys(%{exit_page: :name})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        to_csv(exit_pages, [:name, :visitors, :conversion_rate], [
          :name,
          :conversions,
          :conversion_rate
        ])
      else
        to_csv(exit_pages, [:name, :visitors, :visits, :exit_rate], [
          :name,
          :unique_exits,
          :total_exits,
          :exit_rate
        ])
      end
    else
      json(conn, %{
        results: exit_pages,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def countries(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:country")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    metrics =
      breakdown_metrics(query,
        extra_metrics: [:percentage],
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    countries =
      results
      |> transform_keys(%{country: :code})

    countries_response(conn, query, meta, countries, !!params["csv"])
  end

  defp countries_response(_conn, query, _meta, countries, true = _csv?) do
    countries =
      countries
      |> Enum.map(fn country ->
        country_info = get_country(country[:code])
        Map.put(country, :name, country_info.name)
      end)

    if toplevel_goal_filter?(query) do
      countries
      |> transform_keys(%{visitors: :conversions})
      |> to_csv([:name, :conversions, :conversion_rate])
    else
      countries |> to_csv([:name, :visitors])
    end
  end

  defp countries_response(conn, query, meta, countries, _csv?) do
    countries =
      Enum.map(countries, fn row ->
        country = get_country(row[:code])

        if country do
          Map.merge(row, %{
            name: country.name,
            flag: country.flag,
            alpha_3: country.alpha_3,
            code: country.alpha_2
          })
        else
          Map.merge(row, %{
            name: row[:code],
            flag: "",
            alpha_3: "",
            code: ""
          })
        end
      end)

    json(conn, %{
      results: countries,
      meta: Stats.Breakdown.formatted_date_ranges(query),
      skip_imported_reason: meta[:imports_skip_reason]
    })
  end

  def regions(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:region")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    metrics =
      breakdown_metrics(query,
        extra_metrics: [:percentage],
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    regions =
      results
      |> transform_keys(%{region: :code})
      |> Enum.map(fn region ->
        region_entry = Location.get_subdivision(region[:code])

        if region_entry do
          country_entry = get_country(region_entry.country_code)
          Map.merge(region, %{name: region_entry.name, country_flag: country_entry.flag})
        else
          Logger.warning("Could not find region info - code: #{inspect(region[:code])}")
          Map.merge(region, %{name: region[:code]})
        end
      end)

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        regions
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        regions |> to_csv([:name, :visitors])
      end
    else
      json(conn, %{
        results: regions,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def cities(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:city")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    metrics =
      breakdown_metrics(query,
        extra_metrics: [:percentage],
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    cities =
      results
      |> transform_keys(%{city: :code})
      |> Enum.map(fn city ->
        city_info = Location.get_city(city[:code])

        if city_info do
          country_info = get_country(city_info.country_code)

          Map.merge(city, %{
            name: city_info.name,
            country_flag: country_info.flag
          })
        else
          Logger.warning("Could not find city info - code: #{inspect(city[:code])}")

          Map.merge(city, %{name: "N/A"})
        end
      end)

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        cities
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        cities |> to_csv([:name, :visitors])
      end
    else
      json(conn, %{
        results: cities,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def browsers(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:browser")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    extra_metrics =
      if params["detailed"], do: [:bounce_rate, :visit_duration], else: []

    metrics =
      breakdown_metrics(query,
        extra_metrics: extra_metrics ++ [:percentage],
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    browsers =
      results
      |> transform_keys(%{browser: :name})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        browsers
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        browsers |> to_csv([:name, :visitors])
      end
    else
      json(conn, %{
        results: browsers,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def browser_versions(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:browser_version")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    extra_metrics =
      if params["detailed"], do: [:bounce_rate, :visit_duration], else: []

    metrics =
      breakdown_metrics(query,
        extra_metrics: extra_metrics ++ [:percentage],
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    results =
      results
      |> transform_keys(%{browser_version: :version})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        results
        |> transform_keys(%{browser: :name, visitors: :conversions})
        |> to_csv([:name, :version, :conversions, :conversion_rate])
      else
        results
        |> transform_keys(%{browser: :name})
        |> to_csv([:name, :version, :visitors])
      end
    else
      results =
        if params["detailed"] do
          transform_keys(results, %{version: :name})
        else
          Enum.map(results, &put_combined_name_with_version(&1, :browser))
        end

      json(conn, %{
        results: results,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def operating_systems(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:os")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    extra_metrics =
      if params["detailed"], do: [:bounce_rate, :visit_duration], else: []

    metrics =
      breakdown_metrics(query,
        extra_metrics: extra_metrics ++ [:percentage],
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    systems =
      results
      |> transform_keys(%{os: :name})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        systems
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        systems |> to_csv([:name, :visitors])
      end
    else
      json(conn, %{
        results: systems,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def operating_system_versions(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:os_version")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    extra_metrics =
      if params["detailed"], do: [:bounce_rate, :visit_duration], else: []

    metrics =
      breakdown_metrics(query,
        extra_metrics: extra_metrics ++ [:percentage],
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    results =
      results
      |> transform_keys(%{os_version: :version})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        results
        |> transform_keys(%{os: :name, visitors: :conversions})
        |> to_csv([:name, :version, :conversions, :conversion_rate])
      else
        results
        |> transform_keys(%{os: :name})
        |> to_csv([:name, :version, :visitors])
      end
    else
      results =
        if params["detailed"] do
          transform_keys(results, %{version: :name})
        else
          Enum.map(results, &put_combined_name_with_version(&1, :os))
        end

      json(conn, %{
        results: results,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def screen_sizes(conn, params) do
    site = conn.assigns[:site]
    params = Map.put(params, "property", "visit:device")
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))
    pagination = parse_pagination(params)

    extra_metrics =
      if params["detailed"], do: [:bounce_rate, :visit_duration], else: []

    metrics =
      breakdown_metrics(query,
        extra_metrics: extra_metrics ++ [:percentage],
        include_revenue?: !!params["detailed"]
      )

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    sizes =
      results
      |> transform_keys(%{device: :name})

    if params["csv"] do
      if toplevel_goal_filter?(query) do
        sizes
        |> transform_keys(%{visitors: :conversions})
        |> to_csv([:name, :conversions, :conversion_rate])
      else
        sizes |> to_csv([:name, :visitors])
      end
    else
      json(conn, %{
        results: sizes,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def conversions(conn, params) do
    pagination = parse_pagination(params)

    site =
      Plausible.Repo.preload(conn.assigns.site,
        goals: Plausible.Goals.for_site_query()
      )

    params =
      params
      |> realtime_period_to_30m()
      |> Map.put("property", "event:goal")

    query = Query.from(site, params, debug_metadata: debug_metadata(conn))

    metrics = [:visitors, :events, :conversion_rate] ++ @revenue_metrics

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    conversions =
      results
      |> transform_keys(%{goal: :name})

    if params["csv"] do
      to_csv(conversions, [:name, :visitors, :events], [
        :name,
        :unique_conversions,
        :total_conversions
      ])
    else
      json(conn, %{
        results: conversions,
        meta: Stats.Breakdown.formatted_date_ranges(query),
        skip_imported_reason: meta[:imports_skip_reason]
      })
    end
  end

  def custom_prop_values(conn, params) do
    site = Plausible.Repo.preload(conn.assigns.site, :team)
    prop_key = Map.fetch!(params, "prop_key")

    case Plausible.Props.ensure_prop_key_accessible(prop_key, site.team) do
      :ok ->
        json(conn, breakdown_custom_prop_values(conn, site, params))

      {:error, :upgrade_required} ->
        H.payment_required(
          conn,
          "#{Plausible.Billing.Feature.Props.display_name()} is part of the Plausible Business plan. To get access to this feature, please upgrade your account."
        )
    end
  end

  def all_custom_prop_values(conn, params) do
    site = conn.assigns.site
    query = Query.from(site, params, debug_metadata: debug_metadata(conn))

    prop_names = Plausible.Stats.CustomProps.fetch_prop_names(site, query)

    prop_names =
      if Plausible.Billing.Feature.Props.enabled?(site) do
        prop_names
      else
        prop_names |> Enum.filter(&(&1 in Plausible.Props.internal_keys()))
      end

    if not Enum.empty?(prop_names) do
      values =
        prop_names
        |> Enum.map(fn prop_key ->
          breakdown_custom_prop_values(conn, site, Map.put(params, "prop_key", prop_key))
          |> Map.get(:results)
          |> Enum.map(&Map.put(&1, :property, prop_key))
          |> transform_keys(%{:name => :value})
        end)
        |> Enum.concat()

      percent_or_cr =
        if toplevel_goal_filter?(query),
          do: :conversion_rate,
          else: :percentage

      to_csv(values, [:property, :value, :visitors, :events, percent_or_cr])
    end
  end

  defp breakdown_custom_prop_values(conn, site, %{"prop_key" => prop_key} = params) do
    pagination = parse_pagination(params)
    prefixed_prop = "event:props:" <> prop_key

    params = Map.put(params, "property", prefixed_prop)

    query = Query.from(site, params, debug_metadata: debug_metadata(conn))

    metrics =
      if toplevel_goal_filter?(query) do
        [:visitors, :events, :conversion_rate] ++ @revenue_metrics
      else
        [:visitors, :events, :percentage] ++ @revenue_metrics
      end

    %{results: results, meta: meta} = Stats.breakdown(site, query, metrics, pagination)

    props =
      results
      |> transform_keys(%{prop_key => :name})

    %{
      results: props,
      meta: Stats.Breakdown.formatted_date_ranges(query),
      skip_imported_reason: meta[:imports_skip_reason]
    }
  end

  def current_visitors(conn, _) do
    site = conn.assigns[:site]
    json(conn, Stats.current_visitors(site))
  end

  defp google_api(), do: Application.fetch_env!(:plausible, :google_api)

  def filter_suggestions(conn, params) do
    site = conn.assigns[:site]
    search_query = params["q"]

    if is_nil(search_query) do
      conn
      |> put_status(:bad_request)
      |> json(%{"error" => "Search parameter 'q' is required"})
    else
      query = Query.from(site, params, debug_metadata: debug_metadata(conn))

      json(
        conn,
        Stats.filter_suggestions(site, query, params["filter_name"], search_query)
      )
    end
  end

  def custom_prop_value_filter_suggestions(conn, %{"prop_key" => prop_key} = params) do
    site = conn.assigns[:site]

    query = Query.from(site, params, debug_metadata: debug_metadata(conn))

    json(
      conn,
      Stats.custom_prop_value_filter_suggestions(site, query, prop_key, params["q"])
    )
  end

  defp transform_keys(result, keys_to_replace) when is_map(result) do
    for {key, val} <- result, do: {Map.get(keys_to_replace, key, key), val}, into: %{}
  end

  defp transform_keys(results, keys_to_replace) when is_list(results) do
    Enum.map(results, &transform_keys(&1, keys_to_replace))
  end

  defp parse_pagination(params) do
    limit = to_int(params["limit"], 9)
    page = to_int(params["page"], 1)
    {limit, page}
  end

  defp to_int(string, default) when is_binary(string) do
    case Integer.parse(string) do
      {i, ""} when is_integer(i) ->
        i

      _ ->
        default
    end
  end

  defp to_int(_, default), do: default

  defp to_csv(list, columns), do: to_csv(list, columns, columns)

  defp to_csv(list, columns, column_names) do
    list
    |> Enum.map(fn row -> Enum.map(columns, &row[&1]) end)
    |> (fn res -> [column_names | res] end).()
    |> NimbleCSV.RFC4180.dump_to_iodata()
  end

  defp get_country(code) do
    case Location.get_country(code) do
      nil ->
        Logger.warning("Could not find country info - code: #{inspect(code)}")

        %Location.Country{
          alpha_2: code,
          alpha_3: "N/A",
          name: code,
          flag: nil
        }

      country ->
        country
    end
  end

  defp date_validation_plug(conn, _opts) do
    case parse_date_params(conn.params) do
      {:ok, _dates} -> conn
      {:error, message} when is_binary(message) -> bad_request(conn, message)
    end
  end

  defp validate_required_filters_plug(
         %Plug.Conn{assigns: %{shared_link: %Plausible.Site.SharedLink{segment_id: segment_id}}} =
           conn,
         _opts
       )
       when is_integer(segment_id) do
    case conn.params
         |> get_filters_param()
         |> ensure_expected_segment_filter_present(segment_id) do
      :ok ->
        conn

      :error ->
        bad_request(
          conn,
          "The first filter must be for the segment with id #{segment_id}"
        )
    end
  end

  defp validate_required_filters_plug(conn, _opts), do: conn

  defp get_filters_param(%{"filters" => filters} = _params) when is_binary(filters) do
    JSON.decode!(filters)
  end

  defp get_filters_param(%{"filters" => filters} = _params) when is_list(filters) do
    filters
  end

  defp get_filters_param(_params) do
    nil
  end

  defp ensure_expected_segment_filter_present(
         filters,
         expected_segment_id
       )
       when is_list(filters) do
    case filters do
      [["is", "segment", [segment_id]] | _other_filters] when segment_id == expected_segment_id ->
        :ok

      _ ->
        :error
    end
  end

  defp ensure_expected_segment_filter_present(_filters, _expected_segment_id) do
    :error
  end

  defp parse_date_params(params) do
    params
    |> Map.take(["from", "to", "date"])
    |> Enum.reduce_while({:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case Date.from_iso8601(value) do
        {:ok, date} ->
          {:cont, {:ok, Map.put(acc, key, date)}}

        _ ->
          {:halt,
           {:error,
            "Failed to parse '#{key}' argument. Only ISO 8601 dates are allowed, e.g. `2019-09-07`, `2020-01-01`"}}
      end
    end)
  end

  defp bad_request(conn, message, extra \\ %{}) do
    payload = Map.merge(extra, %{error: message})

    conn
    |> put_status(400)
    |> json(payload)
    |> halt()
  end

  def comparison_query(query) do
    if query.include.compare do
      Comparisons.get_comparison_query(query)
    end
  end

  defp breakdown_metrics(query, opts) do
    extra_metrics = Keyword.get(opts, :extra_metrics, [])
    include_revenue? = Keyword.get(opts, :include_revenue?, false)

    if toplevel_goal_filter?(query) do
      metrics = [:visitors, :conversion_rate, :total_visitors]

      if ee?() and include_revenue? do
        metrics ++ [:average_revenue, :total_revenue]
      else
        metrics
      end
    else
      [:visitors] ++ extra_metrics
    end
  end

  def put_combined_name_with_version(row, name_key) do
    name =
      case {row[name_key], row.version} do
        {@not_set, @not_set} -> @not_set
        {browser_or_os, version} -> "#{browser_or_os} #{version}"
      end

    Map.put(row, :name, name)
  end

  defp realtime_period_to_30m(%{"period" => _} = params) do
    Map.update!(params, "period", fn period ->
      if period == "realtime", do: "30m", else: period
    end)
  end

  defp realtime_period_to_30m(params), do: params

  defp toplevel_goal_filter?(query) do
    Filters.filtering_on_dimension?(query, "event:goal",
      max_depth: 0,
      behavioral_filters: :ignore
    )
  end
end
