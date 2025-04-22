defmodule PlausibleWeb.Live.CustomerSupport do
  @moduledoc """
  LiveView for Team setup
  """

  use PlausibleWeb, :live_view
  alias Plausible.CustomerSupport.Resource

  @resources [Resource.Team, Resource.User, Resource.Site]
  @resources_by_type @resources |> Enum.into(%{}, fn mod -> {mod.type(), mod} end)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, results: [], current: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container pt-6">
      <div class="flex items-center mt-16">
        <form class="w-full">
          <.input value="" name="spotlight" id="spotlight" phx-change="search" />
        </form>
      </div>
      <div id="results" class="mt-8">
        <h1>Results</h1>
        <div :for={r <- @results} class="m-2 p-4 rounded-md border border-gray-300">
          <.styled_link phx-click="open" phx-value-id={r.id} phx-value-type={r.type}>
            <.render_result resource={r} />
          </.styled_link>
        </div>
      </div>
      <div
        id="modal"
        class={[
          if(is_nil(@current), do: "hidden"),
          "fixed inset-0 bg-gray-800 bg-opacity-75 flex items-center justify-center"
        ]}
      >
        <div
          phx-click-away="close"
          class="overflow-auto bg-white w-full h-2/3 max-w-4xl max-h-full p-6 rounded-lg shadow-lg"
        >
          <h2 class="text-xl font-bold mb-4">Details</h2>
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
  def handle_params(%{"id" => id, "resource" => type}, _uri, socket) do
    mod = Map.fetch!(@resources_by_type, type)
    id = String.to_integer(id)
    {:noreply, assign(socket, type: type, current: mod, id: id)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"spotlight" => ""}, socket) do
    {:noreply, assign(socket, results: [])}
  end

  def handle_event("search", %{"spotlight" => input}, socket) do
    results = spawn_searches(input)
    {:noreply, assign(socket, results: results)}
  end

  def handle_event("open", %{"type" => type, "id" => id}, socket) do
    socket = push_patch(socket, to: "/cs/#{type}/#{id}")
    {:noreply, socket}
  end

  def handle_event("close", _, socket) do
    {:noreply, assign(socket, current: nil)}
  end

  defp spawn_searches(input) do
    @resources
    |> Task.async_stream(fn resource ->
      input
      |> resource.search()
      |> Enum.map(&resource.dump/1)
    end)
    |> Enum.reduce([], fn {:ok, results}, acc ->
      acc ++ results
    end)
  end
end
