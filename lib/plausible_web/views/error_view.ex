defmodule PlausibleWeb.ErrorView do
  use PlausibleWeb, :view

  def render("500.json", _assigns) do
    %{
      status: 500,
      message: "Server error"
    }
  end

  def render("404.html", assigns) do
    assigns =
      assigns
      |> Map.put(:status, 404)
      |> Map.put_new(:message, "Oops! There's nothing here")

    render("generic_error.html", assigns)
  end

  def render(<<"5", _error_5xx::binary-size(2), ".html">>, assigns) do
    current_user = assigns[:current_user]
    selfhosted? = Plausible.Release.selfhost?()
    last_event = Sentry.get_last_event_id_and_source()

    case {selfhosted?, current_user, last_event} do
      {false, current_user, {event_id, :plug}}
      when is_binary(event_id) and not is_nil(current_user) ->
        opts = %{
          trace_id: event_id,
          user_name: current_user.name,
          user_email: current_user.email,
          selfhosted?: selfhosted?
        }

        render("server_error.html", Map.merge(opts, assigns))

      _ ->
        render("server_error.html", Map.put(assigns, :selfhosted?, selfhosted?))
    end
  end

  def template_not_found(template, assigns) do
    assigns =
      assigns
      |> Map.put_new(:message, Phoenix.Controller.status_message_from_template(template))
      |> Map.put(:status, String.trim_trailing(template, ".html"))

    render("generic_error.html", assigns)
  end
end
