defmodule Plausible.OAuth.ProtectedResourcesTest do
  use ExUnit.Case, async: true

  alias Plausible.Auth.Scopes
  alias Plausible.OAuth.ProtectedResources

  @mcp ProtectedResources.mcp()

  describe "get_by_url/1" do
    test "does not resolve inexact resource URL" do
      inexact_url = ProtectedResources.get_resource_url(@mcp) <> "/"

      assert {:error, :not_found} =
               ProtectedResources.get_by_url(inexact_url)
    end

    test "resolves a known resource" do
      url = ProtectedResources.get_resource_url(@mcp)

      assert {:ok, @mcp} =
               ProtectedResources.get_by_url(url)
    end
  end

  describe "normalize_requested_scopes/2" do
    test "defaults to the resource's own scopes when nil" do
      supported = @mcp.scopes_supported
      assert {:ok, ^supported} = ProtectedResources.normalize_requested_scopes(nil, @mcp)
    end

    test "defaults to the resource's own scopes when empty" do
      supported = @mcp.scopes_supported
      assert {:ok, ^supported} = ProtectedResources.normalize_requested_scopes("", @mcp)
    end

    test "returns requested scopes in the resource's order" do
      resource = %{
        resource_path: "/foobar",
        scopes_supported: [Scopes.sites_read(), Scopes.stats_read()]
      }

      requested = "#{Scopes.stats_read()} #{Scopes.sites_read()}"

      assert {:ok, [Scopes.sites_read(), Scopes.stats_read()]} ==
               ProtectedResources.normalize_requested_scopes(requested, resource)
    end
  end

  describe "normalize_granted_scopes/2" do
    test "rejects empty scopes" do
      assert {:error, :invalid_scope} =
               ProtectedResources.normalize_granted_scopes([], @mcp)
    end

    test "rejects when any scope is unsupported" do
      assert {:error, :invalid_scope} =
               ProtectedResources.normalize_granted_scopes(
                 [Scopes.sites_read(), "admin:write"],
                 @mcp
               )
    end

    test "returns granted scopes in the resource's order" do
      resource = %{
        resource_path: "/foobar",
        scopes_supported: [Scopes.sites_read(), Scopes.stats_read()]
      }

      assert {:ok, [Scopes.sites_read(), Scopes.stats_read()]} ==
               ProtectedResources.normalize_granted_scopes(
                 [Scopes.stats_read(), Scopes.sites_read()],
                 resource
               )
    end
  end
end
