defmodule PlausibleWeb.CustomerSupport.Components.Search do
  @moduledoc """
  Dedicated search component for Customer Support
  Handles search logic independently from other components
  """
  use PlausibleWeb, :live_component
  alias Plausible.CustomerSupport.Resource
  alias PlausibleWeb.CustomerSupport.Components.SearchResult

  @resources [Resource.Team, Resource.User, Resource.Site]

  def update(%{filter_text: filter_text} = assigns, socket) do
    socket = assign(socket, assigns)
    {:ok, perform_search(socket, filter_text)}
  end

  def handle_event("search-updated", %{"filter_text" => filter_text}, socket) do
    {:noreply, perform_search(socket, filter_text)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <ul :if={@results != []} class="my-6 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
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

      <div
        :if={@results == [] && String.trim(@filter_text) != ""}
        class="text-center py-8 text-gray-500"
      >
        No results found for "{@filter_text}"
      </div>

      <div
        :if={@results == [] && String.trim(@filter_text) == ""}
        class="text-center py-8 text-gray-500"
      >
        Enter a search term to find teams, users, or sites
      </div>
    </div>
    """
  end

  def render_result(assigns) do
    SearchResult.render_result(assigns)
  end

  defp perform_search(socket, filter_text) do
    results = spawn_searches(filter_text)
    assign(socket, :results, results)
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
end
