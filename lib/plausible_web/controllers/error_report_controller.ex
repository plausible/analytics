defmodule PlausibleWeb.ErrorReportController do
  use PlausibleWeb, :controller

  plug PlausibleWeb.RequireAccountPlug

  def submit_error_report(conn, %{
        "error" => %{"trace_id" => trace_id, "user_feedback" => feedback}
      }) do
    if String.length(String.trim(feedback)) > 5 do
      reported_by = "#{conn.assigns.current_user.name} <#{conn.assigns.current_user.email}>"
      email_template = PlausibleWeb.Email.error_report(reported_by, trace_id, feedback)

      Plausible.Mailer.deliver_later(email_template)
    end

    thanks(conn)
  end

  def submit_error_report(conn, _params) do
    thanks(conn)
  end

  defp thanks(conn) do
    conn
    |> put_view(PlausibleWeb.ErrorView)
    |> render("server_error_report_thanks.html",
      layout: {PlausibleWeb.LayoutView, "base_error.html"}
    )
  end
end
