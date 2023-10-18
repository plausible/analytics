defmodule Plausible.Plugins.API.Goals do
  @moduledoc """
  Plugins API context module for Goals.
  All high level Goal operations should be implemented here.
  """

  import Ecto.Query
  import Plausible.Plugins.API.Pagination

  alias Plausible.Repo
  alias PlausibleWeb.Plugins.API.Schemas.Goal.CreateRequest

  @type create_request() ::
          CreateRequest.CustomEvent.t()
          | CreateRequest.Revenue.t()
          | CreateRequest.Pageview.t()

  @spec create(
          Plausible.Site.t(),
          create_request() | list(create_request())
        ) ::
          {:ok, list(Plausible.Goal.t())}
          | {:error, Ecto.Changeset.t()}
          | {:error, :upgrade_required}
  def create(site, goal_or_goals) do
    Repo.transaction(fn -> find_or_create(site, goal_or_goals) end)
  end

  @spec get_goals(Plausible.Site.t(), map()) :: {:ok, Paginator.Page.t()}
  def get_goals(site, params) do
    query = Plausible.Goals.for_site_query(site, preload_funnels?: true)

    {:ok, paginate(query, params, cursor_fields: [{:id, :desc}])}
  end

  @spec get(Plausible.Site.t(), pos_integer()) :: nil | Plausible.Goal.t()
  def get(site, id) when is_integer(id) do
    site
    |> get_query()
    |> where([g], g.id == ^id)
    |> Repo.one()
  end

  defp get_query(site) do
    from g in Plausible.Goal,
      where: g.site_id == ^site.id,
      order_by: [desc: g.id],
      left_join: assoc(g, :funnels),
      group_by: g.id,
      preload: [:funnels]
  end

  defp convert_to_create_params(%CreateRequest.CustomEvent{goal: %{event_name: event_name}}) do
    %{"goal_type" => "event", "event_name" => event_name}
  end

  defp convert_to_create_params(%CreateRequest.Revenue{
         goal: %{event_name: event_name, currency: currency}
       }) do
    %{"goal_type" => "event", "event_name" => event_name, "currency" => currency}
  end

  defp convert_to_create_params(%CreateRequest.Pageview{goal: %{path: page_path}}) do
    %{"goal_type" => "page", "page_path" => page_path}
  end

  defp find_or_create(site, goal_or_goals) do
    goal_or_goals
    |> List.wrap()
    |> Enum.map(fn goal ->
      case Plausible.Goals.find_or_create(site, convert_to_create_params(goal)) do
        {:ok, goal} ->
          goal

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end
end
