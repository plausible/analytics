defmodule PlausibleWeb.OAuth.AuthorizeController do
  @moduledoc """
  OAuth 2.1 authorization controller.

  ### Responsibilities

  #### Render the consent screen

  It's a form for the user to approve or deny the app requesting for authorization.

  #### Handle form submitting

  There's a special Phoenix.Token.sign/verify flow in place to validate that the submitted data
  hasn't been tampered with in between rendering the screen and submitting the approve / deny decision.
  """

  use PlausibleWeb, :controller

  alias Plausible.Auth
  alias Plausible.OAuth
  alias PlausibleWeb.OAuth.AuthorizationRequest
  alias PlausibleWeb.OAuth.AuthorizationResponse

  plug :require_feature_flag
  plug :put_view, PlausibleWeb.AuthView

  @no_team_message "You need to belong to a team before authorizing an application. Please create or join a team and try again."

  @ungrantable_team_message "You cannot grant access to the selected team. Return to the application and start again."

  @rate_limited_message "Too many authorization requests. Wait a minute before trying again."

  @unverified_request_message "This authorization request has expired or could not be verified. Return to the application and start again."

  @doc """
  Renders the consent form if it's valid authorization request. If not, it redirects with an error or renders a local error page.
  """
  def authorize_form(conn, params) do
    with :ok <- rate_limit(conn),
         {:ok, request} <- AuthorizationRequest.build(params) do
      render_consent_form(conn, request)
    else
      {:error, {:rate_limit, _}} -> render_error_page(conn, @rate_limited_message, 429)
      {:redirect_error, request, error} -> redirect_error(conn, request, error)
      {:render_error, message} -> render_error_page(conn, message)
    end
  end

  @doc """
  Handles the user's approve/deny application form submit, turning it into an
  [authorization response](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-authorization-response).
  It redirects with a code if the approve succeeds. In other cases, it redirects with an error or renders a local error page.
  """
  def authorize(conn, params) do
    user = conn.assigns.current_user

    with :ok <- rate_limit(conn),
         {:ok, request} <- AuthorizationRequest.verify(conn, user, params["signed_request"]) do
      do_authorize(conn, user, request, params)
    else
      {:error, {:rate_limit, _}} -> render_error_page(conn, @rate_limited_message, 429)
      {:error, :invalid_signed_request} -> render_error_page(conn, @unverified_request_message)
    end
  end

  defp do_authorize(conn, user, request, %{"action" => "approve"} = params) do
    case granted_team(conn.assigns, params["team"]) do
      %Plausible.Teams.Team{} = team -> approve(conn, user, team, request)
      nil -> render_error_page(conn, @ungrantable_team_message)
    end
  end

  defp do_authorize(conn, _user, request, _params) do
    redirect_back(conn, request, error: "access_denied")
  end

  defp approve(conn, user, team, request) do
    attrs = %{
      client_id: request.client_id,
      client_name: request.client_name,
      redirect_uri: request.redirect_uri,
      code_challenge: request.code_challenge,
      code_challenge_method: request.code_challenge_method,
      scopes: request.scopes,
      resource: request.resource
    }

    case OAuth.create_authorization_code(user, team, attrs) do
      {:ok, code} -> redirect_back(conn, request, code: code)
      {:error, _} -> redirect_back(conn, request, error: "server_error")
    end
  end

  # remove on rollout
  defp require_feature_flag(conn, _opts) do
    if FunWithFlags.enabled?(:mcp, for: conn.assigns.current_user) do
      conn
    else
      conn
      |> put_status(501)
      |> json(%{error: "not_implemented"})
      |> halt()
    end
  end

  defp rate_limit(conn) do
    with :ok <- Auth.rate_limit(:oauth_authorize_ip, conn) do
      Auth.rate_limit(:oauth_authorize_user, conn.assigns.current_user)
    end
  end

  # This currently needs no filtering for role.
  # `Plausible.Auth.UserSessions` preloads memberships with `on: tm.role != :guest`,
  # and `:guest` is the one role `Plausible.OAuth` will not issue a grant for.
  defp grantable_teams(assigns) do
    case assigns[:my_team] do
      nil -> assigns[:teams] || []
      my_team -> [my_team | assigns[:teams] || []]
    end
  end

  defp preselected_team(assigns) do
    teams = grantable_teams(assigns)
    identifier = assigns[:current_team] && assigns[:current_team].identifier

    Enum.find(teams, List.first(teams), &(&1.identifier == identifier))
  end

  defp granted_team(assigns, identifier) do
    Enum.find(grantable_teams(assigns), &(&1.identifier == identifier))
  end

  defp render_consent_form(conn, request) do
    case preselected_team(conn.assigns) do
      nil ->
        render_error_page(conn, @no_team_message)

      selected_team ->
        render(conn, "oauth_authorize.html",
          legacy_layout?: false,
          request: request,
          grantable_teams: grantable_teams(conn.assigns),
          selected_team: selected_team,
          signed_request: AuthorizationRequest.sign(conn, conn.assigns.current_user, request)
        )
    end
  end

  defp render_error_page(conn, message, status \\ 400) do
    conn
    |> put_status(status)
    |> render("oauth_error.html", legacy_layout?: false, message: message)
  end

  defp redirect_error(conn, %{redirect_uri: redirect_uri, state: state}, error) do
    redirect(conn,
      external: AuthorizationResponse.redirect_url(redirect_uri, error: error, state: state)
    )
  end

  defp redirect_back(conn, request, params) do
    redirect(conn,
      external:
        AuthorizationResponse.redirect_url(request.redirect_uri, params ++ [state: request.state])
    )
  end
end
