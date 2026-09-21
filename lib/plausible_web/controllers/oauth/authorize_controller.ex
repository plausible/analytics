defmodule PlausibleWeb.OAuth.AuthorizeController do
  @moduledoc """
  OAuth 2.1 authorization controller.
  """

  use PlausibleWeb, :controller

  alias Plausible.OAuth
  alias Plausible.OAuth.CIMD
  alias Plausible.OAuth.ProtectedResources

  plug :put_view, PlausibleWeb.AuthView

  @no_team_message "You need to belong to a team before authorizing an application. Please create or join a team and try again."

  @doc """
  Validates an incoming [authorization request](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-authorization-request)
  and renders the consent screen for the logged-in user.
  """
  def authorize_form(conn, params) do
    if conn.assigns[:current_user] do
      case build_context(params) do
        {:ok, ctx} -> render_consent(conn, ctx)
        {:redirect_error, request, error} -> redirect_error(conn, request, error)
        {:render_error, message} -> render_error_page(conn, message)
      end
    else
      redirect_to_login(conn)
    end
  end

  @doc """
  Turns the user's approve/deny decision into an
  [authorization response](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-authorization-response),
  redirecting back to the client with a code or an error.
  """
  def authorize(conn, %{"action" => action} = params) do
    user = conn.assigns[:current_user]

    if is_nil(user) do
      redirect_to_login(conn)
    else
      case build_context(params) do
        {:ok, ctx} -> handle_decision(conn, user, ctx, action)
        {:redirect_error, request, error} -> redirect_error(conn, request, error)
        {:render_error, message} -> render_error_page(conn, message)
      end
    end
  end

  def authorize(conn, params), do: authorize(conn, Map.put(params, "action", "deny"))

  defp handle_decision(conn, user, ctx, "approve") do
    case resolve_team(conn, ctx) do
      nil ->
        render_error_page(conn, @no_team_message)

      team ->
        attrs = %{
          client_id: ctx.client_id,
          client_name: ctx.client_name,
          redirect_uri: ctx.redirect_uri,
          code_challenge: ctx.code_challenge,
          code_challenge_method: ctx.code_challenge_method,
          scopes: ctx.scopes,
          resource: ctx.resource
        }

        case OAuth.create_authorization_code(user, team, attrs) do
          {:ok, code} ->
            redirect(conn,
              external: redirect_with(ctx.redirect_uri, code: code, state: ctx.state)
            )

          {:error, _} ->
            redirect_error(conn, ctx, "server_error")
        end
    end
  end

  defp handle_decision(conn, _user, ctx, _denied_or_unknown) do
    redirect_error(conn, ctx, "access_denied")
  end

  defp resolve_team(conn, ctx) do
    team =
      case ctx.team do
        nil -> conn.assigns[:current_team]
        identifier -> Enum.find(conn.assigns[:teams] || [], &(&1.identifier == identifier))
      end

    team || conn.assigns[:current_team]
  end

  defp build_context(params) do
    request = authorization_request(params)

    with {:ok, metadata} <- fetch_client_metadata(request.client_id),
         :ok <- validate_redirect_uri(request.redirect_uri, metadata) do
      build_context_with_validated_redirect_uri(request, metadata)
    end
  end

  defp authorization_request(params) do
    %{
      client_id: params["client_id"],
      redirect_uri: params["redirect_uri"],
      response_type: params["response_type"],
      code_challenge: params["code_challenge"],
      code_challenge_method: params["code_challenge_method"],
      scope: params["scope"],
      resource: params["resource"],
      state: params["state"],
      team: params["team"]
    }
  end

  defp build_context_with_validated_redirect_uri(request, metadata) do
    cond do
      request.response_type != "code" ->
        {:redirect_error, request, "unsupported_response_type"}

      blank?(request.code_challenge) ->
        {:redirect_error, request, "invalid_request"}

      request.code_challenge_method != "S256" ->
        {:redirect_error, request, "invalid_request"}

      true ->
        with {:ok, resource} <- ProtectedResources.get_by_url(request.resource),
             {:ok, scopes} <-
               ProtectedResources.normalize_requested_scopes(request.scope, resource) do
          {:ok,
           %{
             client_id: request.client_id,
             redirect_uri: request.redirect_uri,
             response_type: request.response_type,
             code_challenge: request.code_challenge,
             code_challenge_method: request.code_challenge_method,
             scopes: scopes,
             resource: ProtectedResources.get_resource_url(resource),
             state: request.state,
             team: request.team,
             client_name: metadata["client_name"]
           }}
        else
          {:error, :not_found} -> {:redirect_error, request, "invalid_target"}
          {:error, :invalid_scope} -> {:redirect_error, request, "invalid_scope"}
        end
    end
  end

  defp fetch_client_metadata(client_id) when is_binary(client_id) and client_id != "" do
    case CIMD.fetch(client_id) do
      {:ok, metadata} -> {:ok, metadata}
      {:error, _} -> {:render_error, "Invalid or unreachable client_id metadata document."}
    end
  end

  defp fetch_client_metadata(_), do: {:render_error, "Missing or invalid client_id."}

  defp validate_redirect_uri(redirect_uri, metadata) do
    if CIMD.redirect_uri_registered?(redirect_uri, metadata["redirect_uris"] || []) do
      :ok
    else
      {:render_error,
       "The redirect_uri does not match any registered redirect URI for this client."}
    end
  end

  defp render_consent(conn, ctx) do
    if is_nil(resolve_team(conn, ctx)) do
      render_error_page(conn, @no_team_message)
    else
      render(conn, "oauth_authorize.html",
        legacy_layout?: false,
        ctx: ctx,
        teams: conn.assigns[:teams] || [],
        current_team: conn.assigns[:current_team]
      )
    end
  end

  defp render_error_page(conn, message) do
    conn
    |> put_status(400)
    |> render("oauth_error.html", legacy_layout?: false, message: message)
  end

  defp redirect_error(conn, %{redirect_uri: redirect_uri, state: state}, error) do
    redirect(conn, external: redirect_with(redirect_uri, error: error, state: state))
  end

  defp redirect_with(redirect_uri, params) do
    query = params |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> URI.encode_query()
    uri = URI.parse(redirect_uri)

    merged =
      case uri.query do
        empty when empty in [nil, ""] -> query
        existing -> existing <> "&" <> query
      end

    URI.to_string(%{uri | query: merged})
  end

  defp redirect_to_login(conn) do
    return_to = conn.request_path <> query_suffix(conn.query_string)
    redirect(conn, to: Routes.auth_path(conn, :login_form, return_to: return_to))
  end

  defp query_suffix(""), do: ""
  defp query_suffix(qs), do: "?" <> qs

  defp blank?(value), do: is_nil(value) or value == ""
end
