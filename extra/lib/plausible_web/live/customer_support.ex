defmodule PlausibleWeb.Live.CustomerSupport do
  @moduledoc """
  Customer Support UI
  """
  use PlausibleWeb, :live_view
  alias Plausible.CustomerSupport.Resource

  @resources [Resource.Team, Resource.User, Resource.Site]
  @resources_by_type @resources |> Enum.into(%{}, fn mod -> {mod.type(), mod} end)

  @impl true
  def mount(params, _session, socket) do
    uri =
      ("/cs?" <> URI.encode_query(Map.take(params, ["filter_text"])))
      |> URI.new!()

    {:ok,
     assign(socket,
       resources_by_type: @resources_by_type,
       results: [],
       current: nil,
       uri: uri,
       filter_text: params["filter_text"] || ""
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.flash_messages flash={@flash} />

    <div class="container pt-6">
      <div class="group mt-6 pb-5 border-b border-gray-200 dark:border-gray-500 flex items-center justify-between">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 dark:text-gray-100 sm:text-3xl sm:leading-9 sm:truncate flex-shrink-0">
          💬 Customer Support
        </h2>
      </div>

      <div class="border-t border-gray-200 pt-4 sm:flex sm:items-center sm:justify-between mb-4">
        <form id="filter-form" phx-change="search" action={@uri} method="GET">
          <div class="text-gray-800 text-sm inline-flex items-center w-full">
            <div class="relative rounded-md flex">
              <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                <Heroicons.magnifying_glass class="feather mr-1 dark:text-gray-300" />
              </div>
              <input
                type="text"
                name="filter_text"
                id="filter-text"
                phx-debounce={200}
                class="pl-8 dark:bg-gray-900 dark:text-gray-300 focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 dark:border-gray-500 rounded-md"
                placeholder="Press / to search"
                phx-click="close"
                autocomplete="off"
                value={@filter_text}
                x-ref="filter_text"
                x-on:keydown.escape="$refs.filter_text.blur(); $refs.reset_filter?.dispatchEvent(new Event('click', {bubbles: true, cancelable: true}));"
                x-on:keydown.prevent.slash.window="$refs.filter_text.focus(); $refs.filter_text.select();"
                x-on:blur="$refs.filter_text.placeholder = 'Press / to search"
                x-on:focus="$refs.filter_text.placeholder = 'Search';"
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

            <div class="ml-8"></div>
          </div>
        </form>
      </div>

      <ul :if={!@current} class="my-6 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <li :for={r <- @results} class="group relative">
          <.link patch={"/cs/#{r.type}s/#{r.type}/#{r.id}"}>
            <div class="col-span-1 bg-white dark:bg-gray-800 rounded-lg shadow p-4 group-hover:shadow-lg cursor-pointer">
              <div class="text-gray-800 dark:text-gray-500 w-full flex items-center justify-between space-x-4">
                <.render_result resource={r} />
              </div>
            </div>
          </.link>
        </li>
      </ul>

      <div
        id="modal"
        class={[
          if(is_nil(@current), do: "hidden")
        ]}
      >
        <div class="overflow-auto bg-white dark:bg-gray-800 text-gray-800 dark:text-gray-300 w-full h-3/4 max-w-7xl max-h-full p-4 rounded-lg shadow-lg">
          <div class="flex justify-between text-xs">
            <.styled_link onclick="window.history.go(-1); return false;">
              &larr; Previous
            </.styled_link>
            <.styled_link
              :if={@current}
              class="text-xs"
              new_tab={true}
              href={kaffy_url(@current, @id)}
            >
              open in Kaffy
            </.styled_link>
          </div>
          <.live_component
            :if={@current}
            module={@current.component()}
            resource_id={@id}
            id={"#{@current.type()}-#{@id}"}
          />
        </div>
      </div>
    </div>
    """
  end

  def render_result(assigns) do
    apply(assigns.resource.module.component(), :render_result, [assigns])
  end

  @impl true
  def handle_params(%{"id" => id, "resource" => type} = p, _uri, socket) do
    mod = Map.fetch!(@resources_by_type, type)

    id = String.to_integer(id)

    send_update(self(), mod.component(),
      id: "#{mod.type()}-#{id}",
      tab: p["tab"]
    )

    {:noreply, assign(socket, type: type, current: mod, id: id)}
  end

  def handle_params(%{"filter_text" => _}, _uri, socket) do
    socket =
      search(assign(socket, current: nil))

    {:noreply, socket}
  end

  def handle_params(_, _uri, socket) do
    {:noreply, search(socket)}
  end

  def search(%{assigns: assigns} = socket) do
    results = spawn_searches(assigns.filter_text)
    assign(socket, results: results)
  end

  @impl true
  def handle_event("search", %{"filter_text" => input}, socket) do
    socket = set_filter_text(socket, input)
    {:noreply, socket}
  end

  def handle_event("reset-filter-text", _params, socket) do
    socket = set_filter_text(socket, "")
    {:noreply, socket}
  end

  def handle_event("close", _, socket) do
    {:noreply, assign(socket, current: nil)}
  end

  def handle_info({:success, msg}, socket) do
    {:noreply, put_live_flash(socket, :success, msg)}
  end

  def handle_info({:failure, msg}, socket) do
    {:noreply, put_live_flash(socket, :error, msg)}
  end

  defp spawn_searches(input) do
    input = String.trim(input)

    {resources, input, limit} =
      maybe_focus_search(input)

    resources
    |> Task.async_stream(fn resource ->
      input
      |> resource.search(limit)
      |> Enum.map(&resource.dump/1)
    end)
    |> Enum.reduce([], fn {:ok, results}, acc ->
      acc ++ results
    end)
  end

  defp maybe_focus_search(lone_modifier) when lone_modifier in ["site:", "team:", "user:"] do
    {[], "", 0}
  end

  defp maybe_focus_search("site:" <> rest) do
    {[Resource.Site], rest, 90}
  end

  defp maybe_focus_search("team:" <> rest) do
    {[Resource.Team], rest, 90}
  end

  defp maybe_focus_search("user:" <> rest) do
    {[Resource.User], rest, 90}
  end

  defp maybe_focus_search(input) do
    {@resources, input, 30}
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
    |> push_patch(to: URI.to_string(uri))
  end

  defp kaffy_url(nil, _id), do: ""

  defp kaffy_url(current, id) do
    r =
      current.type()

    kaffy_r =
      case r do
        "user" -> "auth"
        "team" -> "teams"
        "site" -> "sites"
      end

    "/crm/#{kaffy_r}/#{r}/#{id}"
  end
end
