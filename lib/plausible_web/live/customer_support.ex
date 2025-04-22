defmodule PlausibleWeb.Live.CustomerSupport do
  @moduledoc """
  LiveView for Team setup
  """

  use PlausibleWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    IO.inspect(:mount)
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
            <div class="flex items-center">
              <.icon for={r.type} />
              {r.text}
            </div>
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

  def dynamic_component(assigns) do
    {mod, assigns} = Map.pop(assigns, :module)

    apply(mod, :render, [assigns])
  end

  def icon(assigns) do
    ~H"""
    <div class="mr-4">
      <Heroicons.user :if={@for == "user"} class="h-8 w-8" />
      <Heroicons.user_group :if={@for == "team"} class="h-8 w-8" />
      <Heroicons.document :if={@for == "site"} class="h-8 w-8" />
    </div>
    """
  end

  import Ecto.Query

  defmodule Option do
    defstruct [:id, :text, :type, :module]

    def new(search_mod, id, text) do
      %Option{
        id: id,
        text: text,
        type: search_mod.type(),
        module: search_mod
      }
    end
  end

  defmodule Search.User do
    def type(), do: "user"

    def component(), do: PlausibleWeb.CustomerSupport.LiveUser

    def run(input) do
      q =
        from u in Plausible.Auth.User,
          select: %{
            user: u,
            score:
              fragment(
                "CASE WHEN ? ILIKE ? THEN 2 WHEN ? ILIKE ? THEN 1 ELSE 0 END AS score",
                u.email,
                ^"%#{input}%",
                u.name,
                ^"%#{input}%"
              )
          },
          where:
            fragment(
              "? ILIKE ? OR ? ILIKE ?",
              u.email,
              ^"%#{input}%",
              u.name,
              ^"%#{input}%"
            ),
          order_by: fragment("score desc"),
          limit: 10

      Plausible.Repo.all(q)
    end

    def to_option(u) do
      Option.new(__MODULE__, u.user.id, "User: #{u.user.name} <#{u.user.email}>")
    end

    def handle("delete", id) do
      raise "delete #{id}"
    end
  end

  defmodule Search.Team do
    def component, do: PlausibleWeb.CustomerSupport.LiveTeam
    def type, do: "team"

    def run(input) do
      q =
        from t in Plausible.Teams.Team,
          inner_join: o in assoc(t, :owners),
          or_where: ilike(t.name, ^"%#{input}%"),
          or_where: ilike(o.name, ^"%#{input}%"),
          limit: 10,
          preload: [owners: o]

      Plausible.Repo.all(q)
    end

    def to_option(t) do
      Option.new(
        __MODULE__,
        t.id,
        "Team: #{t.name} #{t.identifier} owned by #{Enum.join(Enum.map(t.owners, & &1.name), ",")}"
      )
    end
  end

  defmodule Search.Site do
    def component, do: PlausibleWeb.CustomerSupport.LiveSite
    def type, do: "site"

    def run(input) do
      q =
        from s in Plausible.Site,
          inner_join: t in assoc(s, :team),
          inner_join: o in assoc(t, :owners),
          or_where: ilike(s.domain, ^"%#{input}%"),
          or_where: ilike(t.name, ^"%#{input}%"),
          or_where: ilike(o.name, ^"%#{input}%"),
          limit: 10,
          preload: [team: {t, owners: o}]

      Plausible.Repo.all(q)
    end

    def to_option(s) do
      Option.new(
        __MODULE__,
        s.id,
        "Site: #{s.domain} (team: #{s.team.name} #{s.team.identifier} owned by #{Enum.join(Enum.map(s.team.owners, & &1.name), ",")})"
      )
    end
  end

  def suggest(input) do
    input
    |> spawn_searches()
    |> Enum.to_list()
  end

  @searches [Search.Team, Search.User, Search.Site]
  @searches_by_type @searches |> Enum.into(%{}, fn mod -> {mod.type(), mod} end)

  def spawn_searches(input) do
    @searches
    |> Task.async_stream(fn search ->
      input
      |> search.run()
      |> Enum.map(&search.to_option/1)
    end)
    |> Enum.reduce([], fn {:ok, results}, acc ->
      acc ++ results
    end)
  end

  @impl true
  def handle_params(%{"id" => id, "resource" => type}, _uri, socket) do
    mod = Map.fetch!(@searches_by_type, type)
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
end
