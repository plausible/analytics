defmodule PlausibleWeb.ErrorView do
  use PlausibleWeb, :view

  def render("500.json", _assigns) do
    %{
      status: 500,
      message: "Server error"
    }
  end

  def render("404.html", assigns) do
    render(
      "error.html",
      Map.merge(
        %{
          layout: false,
          status: 404,
          message: "Oops! There's nothing here"
        },
        assigns
      )
    )
  end

  def render("500.html", assigns) do
    render(
      "error.html",
      Map.merge(
        %{
          layout: false,
          status: 500,
          message: "Oops! Looks like we're having server issues"
        },
        assigns
      )
    )
  end

  def template_not_found(template, assigns) do
    status = String.trim_trailing(template, ".html")

    render(
      "error.html",
      Map.merge(
        %{
          layout: false,
          status: status,
          message: Phoenix.Controller.status_message_from_template(template)
        },
        assigns
      )
    )
  end
end
