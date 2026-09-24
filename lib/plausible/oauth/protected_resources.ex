defmodule Plausible.OAuth.ProtectedResources do
  @moduledoc """
  The protected resources the OAuth authorization server will issue tokens for.
  Each authorization grant is associated with a particular resource.

  Resources are identified by clients by their full URL, e.g. "https://plausible.io/mcp".
  """

  @type t() :: %{
          resource_path: String.t(),
          scopes_supported: [String.t()]
        }

  @spec mcp() :: t()
  def mcp(),
    do: %{
      resource_path: "/mcp",
      scopes_supported: [Plausible.Auth.Scopes.sites_read()]
    }

  defp resources(), do: [mcp()]

  @spec all() :: [String.t()]
  def all(), do: Enum.map(resources(), &get_resource_url/1)

  @spec get_resource_url(t()) :: String.t()
  def get_resource_url(resource), do: PlausibleWeb.Endpoint.url() <> resource.resource_path

  @spec get_by_url(String.t()) :: {:ok, t()} | {:error, :not_found}
  def get_by_url(resource_url) when is_binary(resource_url) do
    Enum.find_value(resources(), {:error, :not_found}, fn resource ->
      if get_resource_url(resource) == resource_url, do: {:ok, resource}
    end)
  end

  def get_by_url(_resource_url), do: {:error, :not_found}

  @doc """
  Normalizes a space-delimited `scope` request parameter.
  Defaults to all scopes that the resource supports.
  """
  @spec normalize_requested_scopes(String.t() | nil, t()) ::
          {:ok, [String.t()]} | {:error, :invalid_scope}
  def normalize_requested_scopes(scope, resource) when is_nil(scope) or is_binary(scope) do
    case String.split(scope || "", " ", trim: true) do
      [] -> {:ok, resource.scopes_supported}
      requested -> normalize_granted_scopes(requested, resource)
    end
  end

  def normalize_requested_scopes(_scope, _resource), do: {:error, :invalid_scope}

  @doc """
  Normalizes a scopes list to the order the resource specifies.
  Rejects the whole list if it names a scope the resource does not support,
  which can happen when a scope is withdrawn (or refactored) after the list was stored.
  """
  @spec normalize_granted_scopes([String.t()], t()) ::
          {:ok, [String.t()]} | {:error, :invalid_scope}
  def normalize_granted_scopes(scopes, resource) when is_list(scopes) and scopes != [] do
    supported = resource.scopes_supported

    if Enum.all?(scopes, &(&1 in supported)) do
      {:ok, Enum.filter(supported, &(&1 in scopes))}
    else
      {:error, :invalid_scope}
    end
  end

  def normalize_granted_scopes(_scopes, _resource), do: {:error, :invalid_scope}
end
