defmodule PlausibleWeb.Plugs.RecordApiRequest do
  @moduledoc """
  Records each REST API request in `Plausible.ApiRequestLog` when the
  response is sent, including errors from later plugs.

  The request is recorded under the team of `:current_credential`. A
  legacy key has no team, so it uses the team of the verified `:site`.
  Without a team, the request is recorded with team `0`. A 2xx is
  billable, unless a super admin made it.

  Recording is best-effort. A failure is logged and never changes the
  response.
  """

  import Plug.Conn

  require Logger

  alias Plausible.ApiRequestLog
  alias Plausible.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
    register_before_send(conn, &record/1)
  end

  defp record(%{assigns: %{current_credential: credential}} = conn) do
    ApiRequestLog.record(%{
      team_id: team_id(conn, credential),
      credential: credential,
      interface: :rest,
      operation: operation(conn),
      status: conn.status,
      billable: conn.status in 200..299 and not Auth.super_admin?(credential.user_id),
      request_id: conn |> get_resp_header("x-request-id") |> List.first(),
      user_agent: conn |> get_req_header("user-agent") |> List.first("")
    })

    conn
  rescue
    e ->
      log = "Failed to record API request:\n\n  " <> Exception.format(:error, e, __STACKTRACE__)
      Logger.error(log, crash_reason: {e, __STACKTRACE__})
      conn
  end

  defp record(conn), do: conn

  defp team_id(_conn, %{team_id: team_id}) when is_integer(team_id), do: team_id
  defp team_id(%{assigns: %{site: site}}, _credential), do: site.team_id
  defp team_id(_conn, _credential), do: nil

  defp operation(conn) do
    %{route: route} =
      Phoenix.Router.route_info(
        conn.private.phoenix_router,
        conn.method,
        conn.path_info,
        conn.host
      )

    "#{conn.method} #{route}"
  end
end
