defmodule PlausibleWeb.Plugs.RecordApiRequest do
  @moduledoc """
  Records each REST API request in `Plausible.ApiRequestLog` when the
  response is sent, including errors from later plugs.

  The request is recorded under the team of `:current_credential`. A
  legacy key has no team, so it uses the team of the verified `:site`.
  Without a team, nothing is recorded. A 2xx is billable, unless a super
  admin made it.

  Recording is best-effort. A failure is logged and never changes the
  response.
  """

  import Plug.Conn

  require Logger

  alias Plausible.ApiRequestLog
  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Teams.Team

  def init(opts), do: opts

  def call(conn, _opts) do
    register_before_send(conn, &record/1)
  end

  defp record(%{assigns: %{current_credential: credential}} = conn) do
    team = team(conn, credential)

    if team do
      ApiRequestLog.record(%{
        team: team,
        credential: credential,
        interface: :rest,
        operation: operation(conn),
        status: conn.status,
        billable: conn.status in 200..299 and not Auth.super_admin?(credential.user_id),
        request_id: conn |> get_resp_header("x-request-id") |> List.first(),
        user_agent: conn |> get_req_header("user-agent") |> List.first("")
      })
    end

    conn
  rescue
    e ->
      log = "Failed to record API request:\n\n  " <> Exception.format(:error, e, __STACKTRACE__)
      Logger.error(log, crash_reason: {e, __STACKTRACE__})
      conn
  end

  defp record(conn), do: conn

  defp team(_conn, %{team: %Team{} = team}), do: team
  defp team(%{assigns: %{site: site}}, _credential), do: Repo.preload(site, :team).team
  defp team(_conn, _credential), do: nil

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
