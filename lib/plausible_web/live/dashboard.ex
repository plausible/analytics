defmodule PlausibleWeb.Live.Dashboard do
  @moduledoc """
  LV version of pages breakdown.
  """

  use PlausibleWeb, :live_view

  alias Plausible.Stats.Query

  def mount(_params, %{"domain" => domain, "url" => url} = session, socket) do
    user_prefs = get_connect_params(socket)["user_prefs"] || %{}
    current_user = socket.assigns[:current_user]

    site =
      current_user
      |> Plausible.Sites.get_for_user(domain)
      |> Plausible.Repo.preload(:owners)

    socket =
      socket
      |> assign(:site, site)
      |> assign(:user_prefs, user_prefs)
      |> assign(:modal, nil)

    params = Map.drop(session, ["domain", "site_id", "url"])

    {:noreply, socket} = handle_params_internal(params, url, socket)

    {:ok, assign(socket, params: params)}
  end

  def handle_params_internal(params, url, socket) do
    uri = URI.parse(url)

    filters =
      (uri.query || "")
      |> String.split("&")
      |> Enum.map(&parse_filter/1)
      |> Enum.filter(&Function.identity/1)
      |> Jason.encode!()

    params = Map.put(params, "filters", filters)

    query = Query.from(socket.assigns.site, params, %{})

    modal = uri.path |> String.split("/") |> Enum.at(2)

    socket =
      if modal do
        socket
        |> Prima.Modal.push_open("details-#{modal}-breakdown-modal")
        |> assign(:modal, modal)
      else
        socket
        |> Prima.Modal.push_close("details-#{modal}-breakdown-modal")
        |> assign(:modal, nil)
      end

    socket = assign(socket, :query, query)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="live-dashboard-container">
      <.portal id="pages-breakdown-live-container" target="#pages-breakdown-live">
        <.live_component
          module={PlausibleWeb.Live.Dashboard.Pages}
          id="pages-breakdown-component"
          params={@params}
          site={@site}
          query={@query}
          user_prefs={@user_prefs}
        >
        </.live_component>
      </.portal>
      <.live_component
        module={PlausibleWeb.Live.Dashboard.Details.Pages}
        id="details-pages-breakdown-component"
        params={@params}
        site={@site}
        query={@query}
        user_prefs={@user_prefs}
      >
      </.live_component>
    </div>
    """
  end

  def handle_event("handle_dashboard_params", %{"url" => url}, socket) do
    query =
      url
      |> URI.parse()
      |> Map.fetch!(:query)

    params = URI.decode_query(query || "")

    handle_params_internal(params, url, socket)
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
end
