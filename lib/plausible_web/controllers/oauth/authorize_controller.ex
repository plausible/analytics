defmodule PlausibleWeb.OAuth.AuthorizeController do
  @moduledoc """
  OAuth 2.1 authorization controller.

  Fetches CIMD and renders `PlausibleWeb.Live.OAuthAuthorize` or related errors.
  """

  use PlausibleWeb, :controller

  alias Plausible.Auth
  alias PlausibleWeb.OAuth.AuthorizationRequest
  alias PlausibleWeb.OAuth.AuthorizationResponse
  alias PlausibleWeb.OAuth.GrantableTeams

  plug :require_feature_flag
  plug :put_view, PlausibleWeb.AuthView

  @no_team_message "You need to belong to a team before authorizing an application. Please create or join a team and try again."

  @rate_limited_message "Too many authorization requests. Wait a minute before trying again."

  @doc """
  Validates an incoming [authorization request](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-authorization-request)
  and renders the consent screen for the logged-in user.
  """
  def authorize_form(conn, params) do
    with :ok <- rate_limit(conn),
         {:ok, ctx} <- AuthorizationRequest.build(params) do
      render_consent(conn, ctx)
    else
      {:error, {:rate_limit, _}} -> render_error_page(conn, @rate_limited_message, 429)
      {:redirect_error, request, error} -> redirect_error(conn, request, error)
      {:render_error, message} -> render_error_page(conn, message, 400)
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
    with :ok <- Auth.rate_limit(:oauth_authorize_ip, conn),
         :ok <- Auth.rate_limit(:oauth_authorize_user, conn.assigns.current_user) do
      :ok
    end
  end

  defp render_consent(conn, ctx) do
    if GrantableTeams.resolve(conn.assigns, ctx.team) do
      render(conn, "oauth_authorize.html",
        legacy_layout?: false,
        connect_live_socket: true,
        ctx: ctx
      )
    else
      render_error_page(conn, @no_team_message, 400)
    end
  end

  defp render_error_page(conn, message, status) do
    conn
    |> put_status(status)
    |> render("oauth_error.html", legacy_layout?: false, message: message)
  end

  defp redirect_error(conn, %{redirect_uri: redirect_uri, state: state}, error) do
    redirect(conn,
      external: AuthorizationResponse.redirect_url(redirect_uri, error: error, state: state)
    )
  end
end
