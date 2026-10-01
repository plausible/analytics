defmodule PlausibleWeb.OAuth.AuthorizationRequest do
  @moduledoc """
  ### Responsibilities

  - parse query params submitted by the application that is requesting for authorization
  - fetch the app's metadata document
  - validate that the document and params make up a valid [authorization request](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-authorization-request)
  - provide utils to ensure that the valid request can be passed through the user's browser, without being tampered with

  """

  alias Plausible.OAuth.CIMD
  alias Plausible.OAuth.ProtectedResources

  @salt "oauth_authorization_request"
  @max_age_seconds 600

  @typedoc "A validated request, sealed for the round trip by `sign/3`."
  @type signed_request() :: String.t()

  @type t() :: %{
          client_id: String.t(),
          client_name: String.t() | nil,
          redirect_uri: String.t(),
          response_type: String.t(),
          code_challenge: String.t(),
          code_challenge_method: String.t(),
          scopes: [String.t()],
          resource: String.t(),
          state: String.t() | nil
        }

  @doc """
  Builds the authorization request from the parameters the client sent.
  It has three possible outcomes:
  - Valid request, application may be trustworthy, show to user to either approve or deny
  - Invalid request, application may be trustworthy, redirect to application with issue
  - Invalid request, application can't be trusted, no redirect, show error to user
  """
  @spec build(map()) ::
          {:ok, t()} | {:redirect_error, map(), String.t()} | {:render_error, String.t()}
  def build(params) do
    unvalidated = unvalidated_request(params)

    with {:ok, metadata} <- fetch_client_metadata(unvalidated.client_id),
         :ok <- validate_redirect_uri(unvalidated.redirect_uri, metadata) do
      validate_request(unvalidated, metadata)
    end
  end

  @doc """
  Encodes and signs the validated authorization request.
  Needed because the data is passed through the user's browser.
  """
  @spec sign(Plug.Conn.t(), Plausible.Auth.User.t(), t()) :: signed_request()
  def sign(conn, user, request) do
    Phoenix.Token.sign(conn, @salt, %{user_id: user.id, request: request})
  end

  @doc """
  Decodes the validated authorization request.

  Fails for one that is missing, tampered with, older than `#{@max_age_seconds}`
  seconds, or signed for a different user.
  """
  @spec verify(Plug.Conn.t(), Plausible.Auth.User.t(), term()) ::
          {:ok, t()} | {:error, :invalid_signed_request}
  def verify(conn, user, signed_request) when is_binary(signed_request) do
    case Phoenix.Token.verify(conn, @salt, signed_request, max_age: @max_age_seconds) do
      {:ok, %{user_id: user_id, request: request}} when user_id == user.id -> {:ok, request}
      _ -> {:error, :invalid_signed_request}
    end
  end

  def verify(_conn, _user, _signed_request), do: {:error, :invalid_signed_request}

  defp unvalidated_request(params) do
    %{
      client_id: params["client_id"],
      redirect_uri: params["redirect_uri"],
      response_type: params["response_type"],
      code_challenge: params["code_challenge"],
      code_challenge_method: params["code_challenge_method"],
      scope: params["scope"],
      resource: params["resource"],
      state: params["state"]
    }
  end

  defp validate_request(unvalidated, metadata) do
    cond do
      unvalidated.response_type != "code" ->
        {:redirect_error, unvalidated, "unsupported_response_type"}

      blank?(unvalidated.code_challenge) ->
        {:redirect_error, unvalidated, "invalid_request"}

      unvalidated.code_challenge_method != "S256" ->
        {:redirect_error, unvalidated, "invalid_request"}

      true ->
        with {:ok, resource} <- ProtectedResources.get_by_url(unvalidated.resource),
             {:ok, scopes} <-
               ProtectedResources.normalize_requested_scopes(unvalidated.scope, resource) do
          {:ok,
           %{
             client_id: unvalidated.client_id,
             redirect_uri: unvalidated.redirect_uri,
             response_type: unvalidated.response_type,
             code_challenge: unvalidated.code_challenge,
             code_challenge_method: unvalidated.code_challenge_method,
             scopes: scopes,
             resource: ProtectedResources.get_resource_url(resource),
             state: unvalidated.state,
             client_name: metadata["client_name"]
           }}
        else
          {:error, :not_found} -> {:redirect_error, unvalidated, "invalid_target"}
          {:error, :invalid_scope} -> {:redirect_error, unvalidated, "invalid_scope"}
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

  defp blank?(value), do: is_nil(value) or value == ""
end
