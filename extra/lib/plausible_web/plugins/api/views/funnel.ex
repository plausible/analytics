defmodule PlausibleWeb.Plugins.API.Views.Funnel do
  @moduledoc """
  View for rendering Funnels in the Plugins API
  """

  use PlausibleWeb, :plugins_api_view

  def render("index.json", %{
        pagination: %{entries: funnels, metadata: metadata},
        authorized_site: site,
        conn: conn
      }) do
    %{
      funnels:
        render_many(funnels, __MODULE__, "funnel.json", authorized_site: site, as: :funnel),
      meta:
        render_metadata_links(
          metadata,
          fn params -> url(~p"/api/plugins/v1/funnels?#{params}") end,
          conn.query_params
        )
    }
  end

  def render("index.json", %{
        funnels: funnels,
        authorized_site: site,
        conn: conn
      }) do
    %{
      funnels:
        render_many(funnels, __MODULE__, "funnel.json", authorized_site: site, as: :funnel),
      meta:
        render_metadata_links(
          %{},
          fn params -> url(~p"/api/plugins/v1/funnels?#{params}") end,
          conn.query_params
        )
    }
  end

  def render(
        "funnel.json",
        %{
          funnel: funnel,
          authorized_site: site
        }
      ) do
    goals = Enum.map(funnel.steps, & &1.goal)

    %{
      funnel: %{
        name: funnel.name,
        id: funnel.id,
        steps:
          render_many(goals, PlausibleWeb.Plugins.API.Views.Goal, "goal.json",
            authorized_site: site,
            as: :goal
          )
      }
    }
  end
end
