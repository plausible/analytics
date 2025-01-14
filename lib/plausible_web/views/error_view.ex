defmodule PlausibleWeb.ErrorView do
  use Plausible
  use PlausibleWeb, :view

  def render("500.json", %{conn: %{assigns: %{plugins_api: true}}}) do
    contact_support_note =
      on_ee do
        "If the problem persists please contact support@plausible.io"
      end

    %{
      errors: [
        %{detail: "Internal server error, please try again. #{contact_support_note}"}
      ]
    }
  end

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

    render("404_error.html", assigns)
  end

  def render(<<"5", _error_5xx::binary-size(2), ".html">>, assigns) do
    current_user = assigns[:current_user]
    last_event = Sentry.get_last_event_id_and_source()

    case {current_user, last_event} do
      {current_user, {event_id, :plug}}
      when is_binary(event_id) and not is_nil(current_user) ->
        opts = %{
          trace_id: event_id,
          user_name: current_user.name,
          user_email: current_user.email
        }

        render("server_error.html", Map.merge(opts, assigns))

      _ ->
        render("server_error.html", assigns)
    end
  end

  def template_not_found(template, assigns) do
    if String.ends_with?(template, ".json") do
      fallback_json_error(template, assigns)
    else
      fallback_html_error(template, assigns)
    end
  end

  defp fallback_html_error(template, assigns) do
    assigns =
      assigns
      |> Map.put_new(:message, Phoenix.Controller.status_message_from_template(template))
      |> Map.put(:status, String.trim_trailing(template, ".html"))

    render("generic_error.html", assigns)
  end

  defp fallback_json_error(template, _assigns) do
    status =
      String.split(template, ".")
      |> hd()
      |> String.to_integer()

    message = Plug.Conn.Status.reason_phrase(status)
    %{status: status, message: message}
  rescue
    _ -> %{status: 500, message: "Server error"}
  end

  defp url_path(%Plug.Conn{request_path: path, query_string: ""}), do: path
  defp url_path(%Plug.Conn{request_path: path, query_string: query}), do: path <> "?" <> query
end
