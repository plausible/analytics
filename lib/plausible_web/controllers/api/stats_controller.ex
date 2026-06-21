defmodule PlausibleWeb.Api.StatsController do
  use Plausible
  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler

  alias Plausible.Stats

  alias Plausible.Stats.{Query, Dashboard, ParsedQueryParams, QueryBuilder, QueryError}

  alias Plausible.Stats.Dashboard.CsvExport
  alias PlausibleWeb.Api.Helpers, as: H

  require Logger

  plug(:date_validation_plug when action not in [:query, :csv_export_v2])
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
      {:error, %QueryError{message: message}} -> H.bad_request(conn, message)
    end
  end

  def csv_export(conn, params) do
    site = conn.assigns.site

    case CsvExport.get_csvs(site, params, debug_metadata(conn)) do
      {:ok, csvs} ->
        {:ok, {_, zip_content}} = :zip.create(~c"export.zip", csvs, [:memory])

        conn
        |> put_resp_content_type("application/zip")
        |> put_resp_header(
          "content-disposition",
          Plausible.Exports.content_disposition("export.zip")
        )
        |> send_resp(200, zip_content)

      {:error, %QueryError{message: message}} ->
        H.bad_request(conn, message)
    end
  end

  on_ee do
    alias Plausible.Stats.Exploration

    if Mix.env() == :e2e_test do
      @exploration_hourly_limit 100_000
      @exploration_burst_limit 100_000
    else
      @exploration_hourly_limit 600
      @exploration_burst_limit 10
    end

    defp check_exploration_rate_limit(site) do
      key = "exploration:#{site.id}"

      with {:allow, _} <-
             Plausible.RateLimit.check_rate(key, :timer.hours(1), @exploration_hourly_limit),
           {:allow, _} <-
             Plausible.RateLimit.check_rate(key, :timer.seconds(10), @exploration_burst_limit) do
        :ok
      else
        {:deny, _} -> {:error, :rate_limit}
      end
    end

    def exploration_next(conn, %{"journey" => steps} = params) do
      site = conn.assigns.site
      search_term = params["search_term"] || ""

      with :ok <- check_exploration_rate_limit(site),
           {:ok, journey} <- parse_journey(steps),
           {:ok, direction} <- parse_exploration_direction(params["direction"]),
           query = Query.from(site, params, debug_metadata: debug_metadata(conn)),
           {:ok, next_steps} <-
             Exploration.next_steps(site, query, journey,
               search_term: search_term,
               direction: direction
             ) do
        json(conn, next_steps)
      else
        {:error, :rate_limit} ->
          H.too_many_requests(conn, "Too many exploration requests")

        {:error, :journey_too_long} ->
          H.bad_request(conn, "The journey is too long")
      end
    end

    def exploration_funnel(conn, %{"journey" => steps} = params) do
      site = conn.assigns.site

      with :ok <- check_exploration_rate_limit(site),
           {:ok, journey} <- parse_journey(steps),
           {:ok, direction} <- parse_exploration_direction(params["direction"]),
           query = Query.from(site, params, debug_metadata: debug_metadata(conn)),
           {:ok, funnel} <-
             Exploration.journey_funnel(query, journey, direction) do
        json(conn, funnel)
      else
        {:error, :rate_limit} ->
          H.too_many_requests(conn, "Too many exploration requests")

        {:error, :empty_journey} ->
          H.bad_request(conn, "We are unable to show funnels when journey is empty")

        {:error, :journey_too_long} ->
          H.bad_request(conn, "The journey is too long")
      end
    end

    @exploration_max_candidates 50

    def exploration_next_with_funnel(conn, %{"journey" => steps} = params) do
      site = conn.assigns.site
      search_term = params["search_term"] || ""
      include_funnel? = params["include_funnel"] == true

      with :ok <- check_exploration_rate_limit(site),
           {:ok, journey} <- parse_journey(steps),
           {:ok, direction} <- parse_exploration_direction(params["direction"]),
           query = Query.from(site, params, debug_metadata: debug_metadata(conn)),
           {:ok, next_steps} <-
             Exploration.next_steps(site, query, journey,
               search_term: search_term,
               direction: direction,
               max_candidates: @exploration_max_candidates
             ),
           funnel <- maybe_include_funnel(include_funnel?, query, journey, direction) do
        json(conn, %{next: next_steps, funnel: funnel})
      else
        {:error, :rate_limit} ->
          H.too_many_requests(conn, "Too many exploration requests")

        _ ->
          H.bad_request(conn, "There was an error with your request")
      end
    end

    defp maybe_include_funnel(true, query, journey, direction) do
      case Exploration.journey_funnel(query, journey, direction) do
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
           "subpaths_count" => subpaths_count,
           "is_goal" => is_goal
         }) do
      Exploration.Journey.Step.new(
        name,
        pathname,
        includes_subpaths,
        subpaths_count,
        is_goal
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
          H.bad_request(
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
          H.bad_request(conn, "There was an error with your request")
      end
    end

    defp validate_funnel_query(query) do
      cond do
        toplevel_goal_filter?(query) ->
          {:error, {:invalid_funnel_query, "goals"}}

        Plausible.Stats.Filters.filtering_on_dimension?(query, "event:page") ->
          {:error, {:invalid_funnel_query, "pages"}}

        query.input_date_range == :realtime ->
          {:error, {:invalid_funnel_query, "realtime period"}}

        true ->
          :ok
      end
    end
  end

  def google_search_terms(conn, params) do
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

  defp to_int(string, default) when is_binary(string) do
    case Integer.parse(string) do
      {i, ""} when is_integer(i) ->
        i

      _ ->
        default
    end
  end

  defp to_int(_, default), do: default

  defp date_validation_plug(conn, _opts) do
    case parse_date_params(conn.params) do
      {:ok, _dates} -> conn
      {:error, message} when is_binary(message) -> H.bad_request(conn, message)
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
        H.bad_request(
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

  on_ee do
    defp toplevel_goal_filter?(query) do
      Plausible.Stats.Filters.filtering_on_dimension?(query, "event:goal",
        max_depth: 0,
        behavioral_filters: :ignore
      )
    end
  end
end
