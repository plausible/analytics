defmodule Plausible.Plugins.API.Funnels do
  @moduledoc """
  Plugins API context module for Funnels.
  All high level Funnel operations should be implemented here.
  """
  use Plausible

  import Plausible.Pagination

  alias Plausible.Repo
  alias PlausibleWeb.Plugins.API.Schemas.Funnel.CreateRequest

  @type create_request() :: CreateRequest.t()

  @spec create(
          Plausible.Site.t(),
          create_request()
        ) ::
          {:ok, Plausible.Funnel.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :upgrade_required}
  def create(site, create_request) do
    Repo.transaction(fn ->
      with {:ok, goals} <- Plausible.Plugins.API.Goals.create(site, create_request.funnel.steps),
           {:ok, funnel} <- get_or_create(site, create_request.funnel.name, goals) do
        funnel
      else
        {:error, error} ->
          Repo.rollback(error)
      end
    end)
  end

  defp get_or_create(site, name, goals) do
    case get(site, name) do
      %Plausible.Funnel{} = funnel ->
        {:ok, funnel}

      nil ->
        case Plausible.Funnels.create(site, name, goals) do
          {:ok, funnel} ->
            # reload result with steps included
            {:ok, get(site, funnel.id)}

          error ->
            error
        end
    end
  end

  @spec get_funnels(Plausible.Site.t(), map()) :: {:ok, Paginator.Page.t()}
  def get_funnels(site, params) do
    query = Plausible.Funnels.with_goals_query(site)
    {:ok, paginate(query, params, cursor_fields: [{:id, :desc}])}
  end

  @spec get(Plausible.Site.t(), pos_integer() | String.t()) :: nil | Plausible.Funnel.t()
  def get(site, by) when is_integer(by) or is_binary(by) do
    Plausible.Funnels.get(site, by)
  end
end
