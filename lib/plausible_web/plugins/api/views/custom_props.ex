defmodule PlausibleWeb.Plugins.API.Views.CustomProp do
  @moduledoc """
  View for rendering Custom Props in the Plugins API
  """

  use PlausibleWeb, :plugins_api_view

  def render("index.json", %{props: props}) do
    %{
      custom_props: render_many(props, __MODULE__, "custom_prop.json", as: :custom_prop)
    }
  end

  def render("custom_prop.json", %{
        custom_prop: custom_prop
      }) do
    %{
      custom_prop: %{
        key: custom_prop
      }
    }
  end
end
