defmodule PlausibleWeb.OAuth.AuthorizationRequest do
  @moduledoc """
  Validates an incoming [authorization request](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-authorization-request)
  into the context the consent screen renders and the decision is taken against.

  `build/1` is the only place the client's metadata document is fetched during a
  consent round trip. The context it returns travels from the controller into
  the LiveView that takes the decision, so nothing downstream re-reads a
  document the client is free to change in between.
  """

  alias Plausible.OAuth.CIMD
  alias Plausible.OAuth.ProtectedResources

  @type t() :: %{
          client_id: String.t(),
          client_name: String.t() | nil,
          redirect_uri: String.t(),
          response_type: String.t(),
          code_challenge: String.t(),
          code_challenge_method: String.t(),
          scopes: [String.t()],
          resource: String.t(),
          state: String.t() | nil,
          team: String.t() | nil
        }

  @doc """
  Builds the authorization context from request parameters.

  Returns `{:redirect_error, request, error}` for a failure the client is
  entitled to hear about at its `redirect_uri`, and `{:render_error, message}`
  for one that must not be redirected anywhere - an unverified `client_id` or an
  unregistered `redirect_uri` - since that would make this server an open
  redirector for a URL it has not authenticated.
  """
  @spec build(map()) ::
          {:ok, t()} | {:redirect_error, map(), String.t()} | {:render_error, String.t()}
  def build(params) do
    request = authorization_request(params)

    with {:ok, metadata} <- fetch_client_metadata(request.client_id),
         :ok <- validate_redirect_uri(request.redirect_uri, metadata) do
      build_with_validated_redirect_uri(request, metadata)
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

  defp build_with_validated_redirect_uri(request, metadata) do
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

  defp blank?(value), do: is_nil(value) or value == ""
end
