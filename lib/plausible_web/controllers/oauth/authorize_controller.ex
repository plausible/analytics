defmodule PlausibleWeb.OAuth.AuthorizeController do
  @moduledoc """
  OAuth 2.1 authorization endpoint (the consent screen).

  Runs under the `:browser` pipeline so `PlausibleWeb.AuthPlug` populates
  `current_user`; unauthenticated visitors are bounced to `/login` with a
  `return_to` back to the authorize request.

  Client registration is CIMD-only: `client_id` is an HTTPS URL whose metadata
  document is fetched and validated here. The issued authorization code binds the
  approving user and a single selected team, and threads `resource` (RFC 8707)
  and PKCE through to the token exchange.
  """

  use PlausibleWeb, :controller

  alias Plausible.OAuth

  plug :put_view, PlausibleWeb.OAuthView

  @no_team_message "You need to belong to a team before authorizing an application. Please create or join a team and try again."

  def authorize(conn, params) do
    if conn.assigns[:current_user] do
      case build_context(params) do
        {:ok, ctx} ->
          render_consent(conn, ctx)

        {:redirect_error, redirect_uri, state, error} ->
          redirect_error(conn, redirect_uri, state, error)

        {:render_error, message} ->
          render_error_page(conn, message)
      end
    else
      redirect_to_login(conn)
    end
  end

  def consent(conn, %{"action" => action} = params) do
    user = conn.assigns[:current_user]

    if is_nil(user) do
      redirect_to_login(conn)
    else
      case build_context(params) do
        {:ok, ctx} ->
          handle_decision(conn, user, ctx, action)

        {:redirect_error, redirect_uri, state, error} ->
          redirect_error(conn, redirect_uri, state, error)

        {:render_error, message} ->
          render_error_page(conn, message)
      end
    end
  end

  def consent(conn, params), do: consent(conn, Map.put(params, "action", "deny"))

  ## Decision handling

  defp handle_decision(conn, _user, ctx, "deny") do
    redirect_error(conn, ctx.redirect_uri, ctx.state, "access_denied")
  end

  defp handle_decision(conn, user, ctx, "approve") do
    case resolve_team(conn, ctx) do
      nil ->
        # A grant must be bound to exactly one team; refuse to issue a code if the
        # approving user has no resolvable team.
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
            redirect_error(conn, ctx.redirect_uri, ctx.state, "server_error")
        end
    end
  end

  defp handle_decision(conn, _user, ctx, _unknown) do
    redirect_error(conn, ctx.redirect_uri, ctx.state, "access_denied")
  end

  defp resolve_team(conn, ctx) do
    team =
      case ctx.team do
        nil -> conn.assigns[:current_team]
        identifier -> Enum.find(conn.assigns[:teams] || [], &(&1.identifier == identifier))
      end

    team || conn.assigns[:current_team]
  end

  ## Validation

  defp build_context(params) do
    client_id = params["client_id"]
    redirect_uri = params["redirect_uri"]

    with {:ok, metadata} <- fetch_client(client_id),
         :ok <- validate_redirect_uri(redirect_uri, metadata) do
      # From here the redirect_uri is trusted, so protocol errors are redirected
      # back to the client rather than shown as an error page.
      state = params["state"]

      cond do
        params["response_type"] != "code" ->
          {:redirect_error, redirect_uri, state, "unsupported_response_type"}

        blank?(params["code_challenge"]) ->
          {:redirect_error, redirect_uri, state, "invalid_request"}

        params["code_challenge_method"] != "S256" ->
          {:redirect_error, redirect_uri, state, "invalid_request"}

        match?({:error, :invalid_scope}, OAuth.normalize_scopes(params["scope"])) ->
          {:redirect_error, redirect_uri, state, "invalid_scope"}

        true ->
          {:ok, scopes} = OAuth.normalize_scopes(params["scope"])

          {:ok,
           %{
             client_id: client_id,
             redirect_uri: redirect_uri,
             response_type: "code",
             code_challenge: params["code_challenge"],
             code_challenge_method: "S256",
             scopes: scopes,
             resource: params["resource"],
             state: state,
             team: params["team"],
             client_name: metadata["client_name"],
             client_uri: metadata["client_uri"]
           }}
      end
    end
  end

  defp fetch_client(client_id) when is_binary(client_id) and client_id != "" do
    case OAuth.fetch_client_metadata(client_id) do
      {:ok, metadata} -> {:ok, metadata}
      {:error, _} -> {:render_error, "Invalid or unreachable client_id metadata document."}
    end
  end

  defp fetch_client(_), do: {:render_error, "Missing or invalid client_id."}

  defp validate_redirect_uri(redirect_uri, metadata) do
    if OAuth.redirect_uri_registered?(redirect_uri, metadata["redirect_uris"] || []) do
      :ok
    else
      {:render_error,
       "The redirect_uri does not match any registered redirect URI for this client."}
    end
  end

  ## Responses

  defp render_consent(conn, ctx) do
    if is_nil(resolve_team(conn, ctx)) do
      render_error_page(conn, @no_team_message)
    else
      render(conn, "authorize.html",
        ctx: ctx,
        teams: conn.assigns[:teams] || [],
        current_team: conn.assigns[:current_team]
      )
    end
  end

  defp render_error_page(conn, message) do
    conn
    |> put_status(400)
    |> render("error.html", message: message)
  end

  defp redirect_error(conn, redirect_uri, state, error) do
    redirect(conn, external: redirect_with(redirect_uri, error: error, state: state))
  end

  defp redirect_with(redirect_uri, params) do
    query =
      params
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> URI.encode_query()

    uri = URI.parse(redirect_uri)
    existing = uri.query || ""

    merged =
      case existing do
        "" -> query
        _ -> existing <> "&" <> query
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
