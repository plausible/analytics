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
end
