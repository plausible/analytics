defmodule PlausibleWeb.Plugins.API.Views.Goal do
  @moduledoc """
  View for rendering Goals in the Plugins API
  """

  use PlausibleWeb, :plugins_api_view

  def render("index.json", %{
        pagination: %{entries: goals, metadata: metadata},
        authorized_site: site,
        conn: conn
      }) do
    %{
      goals: render_many(goals, __MODULE__, "goal.json", authorized_site: site, as: :goal),
      meta: render_metadata_links(metadata, :plugins_api_goals_url, :index, conn.query_params)
    }
  end

  def render("index.json", %{
        goals: goals,
        authorized_site: site,
        conn: conn
      }) do
    %{
      goals: render_many(goals, __MODULE__, "goal.json", authorized_site: site, as: :goal),
      meta: render_metadata_links(%{}, :plugins_api_goals_url, :index, conn.query_params)
    }
  end

  def render("goal.json", %{
        goal: %{event_name: nil} = pageview
      }) do
    %{
      goal_type: "Goal.Pageview",
      goal: %{
        id: pageview.id,
        display_name: pageview.display_name,
        path: pageview.page_path
      }
    }
  end

  def render("goal.json", %{
        goal: %{page_path: nil, currency: nil} = custom_event
      }) do
    %{
      goal_type: "Goal.CustomEvent",
      goal: %{
        id: custom_event.id,
        display_name: custom_event.display_name,
        event_name: custom_event.event_name
      }
    }
  end

  def render("goal.json", %{
        goal: %{page_path: nil, currency: currency} = revenue_goal
      })
      when is_atom(currency) do
    %{
      goal_type: "Goal.Revenue",
      goal: %{
        id: revenue_goal.id,
        display_name: revenue_goal.display_name,
        event_name: revenue_goal.event_name,
        currency: revenue_goal.currency
      }
    }
  end
end
