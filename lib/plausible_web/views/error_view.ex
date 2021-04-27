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
    case Sentry.get_last_event_id_and_source() do
      {event_id, :plug} when is_binary(event_id) ->
        current_user = assigns[:current_user]

        opts =
          %{
            eventId: event_id,
            user: %{
              name: current_user && current_user.name,
              email: current_user && current_user.email
            }
          }
          |> Jason.encode!()

        ~E"""
        <script src="https://browser.sentry-cdn.com/5.9.1/bundle.min.js" integrity="sha384-/x1aHz0nKRd6zVUazsV6CbQvjJvr6zQL2CHbQZf3yoLkezyEtZUpqUNnOLW9Nt3v" crossorigin="anonymous"></script>
        <script>
        Sentry.init({ dsn: '<%= Sentry.Config.dsn() %>' });
        Sentry.showReportDialog(<%= raw opts %>)
        </script>
        """

      _ ->
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
