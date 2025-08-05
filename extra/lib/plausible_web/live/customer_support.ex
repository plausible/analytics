defmodule PlausibleWeb.Live.CustomerSupport do
  @moduledoc """
  Customer Support home page (search)
  """
  use PlausibleWeb, :live_view

  alias PlausibleWeb.CustomerSupport.Components.{Layout, Search}

  @impl true
  def mount(params, _session, socket) do
    uri =
      Routes.customer_support_path(
        PlausibleWeb.Endpoint,
        :index,
        Map.take(params, ["filter_text"])
      )
      |> URI.new!()

    {:ok,
     assign(socket,
       uri: uri,
       filter_text: params["filter_text"] || ""
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter_text = params["filter_text"] || ""
    socket = assign(socket, filter_text: filter_text)

    send_update(Search, id: "search-component", filter_text: filter_text)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.flash_messages flash={@flash} />

    <Layout.layout filter_text={@filter_text}>
      <.live_component module={Search} filter_text={@filter_text} id="search-component" />
    </Layout.layout>
    """
  end

  @impl true
  def handle_event("filter", %{"filter-text" => input}, socket) do
    socket = set_filter_text(socket, input)
    {:noreply, socket}
  end

  def handle_event("reset-filter-text", _params, socket) do
    socket = set_filter_text(socket, "")
    {:noreply, socket}
  end

  defp set_filter_text(socket, filter_text) do
    uri = socket.assigns.uri

    uri_params =
      (uri.query || "")
      |> URI.decode_query()
      |> Map.put("filter_text", filter_text)
      |> URI.encode_query()

    uri = %{uri | query: uri_params}

    socket
    |> assign(:filter_text, filter_text)
    |> assign(:uri, uri)
    |> push_patch(to: URI.to_string(uri), replace: true)
  end
end
