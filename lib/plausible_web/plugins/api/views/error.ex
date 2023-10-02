defmodule PlausibleWeb.Plugins.API.Views.Error do
  @moduledoc """
  View for rendering Plugins REST API errors
  """
  use PlausibleWeb, :plugins_api_view

  def template_not_found(_template, assigns) do
    render("500.json", assigns)
  end

  @spec render(String.t(), map) :: map | binary()
  def render("400.json", _assigns) do
    %{errors: [%{detail: "Bad request"}]}
  end

  def render("404.json", _assigns) do
    %{errors: [%{detail: "Plugins API: resource not found"}]}
  end

  def render("500.json", _assigns) do
    %{errors: [%{detail: "Plugins API: Internal server error"}]}
  end
end
