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

    <div x-data="{ openHelp: false }">
      <div
        id="help"
        x-show="openHelp"
        x-cloak
        class="p-16 fixed top-0 left-0 w-full h-full bg-gray-800 text-gray-300 bg-opacity-95 z-50 flex items-center justify-center"
      >
        <div @click.away="openHelp = false" @click="openHelp = false">
          Prefix your searches with: <br /><br />
          <div class="font-mono">
            <strong>site:</strong>input<br />
            <p class="font-sans pl-2 mb-1">
              Search for sites exclusively. Input will be checked against site's domain, team's name, owners' names and e-mails.
            </p>
            <strong>user:</strong>input<br />
            <p class="font-sans pl-2 mb-1">
              Search for users exclusively. Input will be checked against user's name and e-mail.
            </p>
            <strong>team:</strong>input<br />
            <p class="font-sans pl-2 mb-1">
              Search for teams exclusively. Input will be checked against user's name and e-mail.
            </p>

            <strong>team:</strong>input <strong>+sub</strong>
            <br />
            <p class="font-sans pl-2 mb-1">
              Like above, but only finds team(s) with subscription (in any status).
            </p>

            <strong>team:</strong>input <strong>+sso</strong>
            <br />
            <p class="font-sans pl-2 mb-1">
              Like above, but only finds team(s) with SSO integrations (in any status).
            </p>
          </div>
        </div>
      </div>

      <div class="container pt-6">
        <div class="group mt-6 pb-5 border-b border-gray-200 dark:border-gray-500 flex items-center justify-between">
          <h2 class="text-2xl font-bold leading-7 text-gray-900 dark:text-gray-100 sm:text-3xl sm:leading-9 sm:truncate flex-shrink-0">
            <.link replace patch="/cs?filter_text=">
              💬 Customer Support
            </.link>
          </h2>
        </div>

        <div class="mb-4 mt-4">
          <.filter_bar filter_text={@filter_text} placeholder="Search everything">
            <a class="cursor-pointer" @click="openHelp = !openHelp">
              <Heroicons.question_mark_circle class="text-indigo-700 dark:text-gray-500 w-5 h-5 hover:stroke-2" />
            </a>
          </.filter_bar>
        </div>

        <ul :if={!@current} class="my-6 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <li :for={r <- @results} class="group relative">
            <.link
              patch={"/cs/#{r.type}s/#{r.type}/#{r.id}"}
              data-test-type={r.type}
              data-test-id={r.id}
            >
              <div class="col-span-1 bg-white dark:bg-gray-800 rounded-lg shadow p-4 group-hover:shadow-lg cursor-pointer">
                <div class="text-gray-800 dark:text-gray-500 w-full flex items-center justify-between space-x-4">
                  <.render_result resource={r} />
                </div>
              </div>
            </.link>
          </li>
        </ul>

        <div class={[
          if(is_nil(@current), do: "hidden")
        ]}>
          <div class="overflow-auto bg-white dark:bg-gray-800 text-gray-800 dark:text-gray-300 w-full h-3/4 max-w-7xl max-h-full p-4 rounded-lg shadow-lg">
            <div class="flex justify-between text-xs">
              <.styled_link onclick="window.history.go(-1); return false;">
                &larr; Previous
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
  def handle_event("filter", %{"filter-text" => input}, socket) do
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

    {resources, input, opts} =
      maybe_focus_search(input)

    resources
    |> Task.async_stream(fn resource ->
      input
      |> resource.search(opts)
      |> Enum.map(&resource.dump/1)
    end)
    |> Enum.reduce([], fn {:ok, results}, acc ->
      acc ++ results
    end)
  end

  defp maybe_focus_search(lone_modifier) when lone_modifier in ["site:", "team:", "user:"] do
    {[], "", limit: 0}
  end

  defp maybe_focus_search("site:" <> rest) do
    {[Resource.Site], rest, limit: 90}
  end

  defp maybe_focus_search("team:" <> rest) do
    [input | mods] = String.split(rest, "+", trim: true)
    input = String.trim(input)

    opts =
      if "sub" in mods do
        [limit: 90, with_subscription_only?: true]
      else
        [limit: 90]
      end

    opts =
      if "sso" in mods do
        Keyword.merge(opts, with_sso_only?: true)
      else
        opts
      end

    {[Resource.Team], input, opts}
  end

  defp maybe_focus_search("user:" <> rest) do
    {[Resource.User], rest, limit: 90}
  end

  defp maybe_focus_search(input) do
    {@resources, input, limit: 30}
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
end
