defmodule PlausibleWeb.Plugs.FeatureFlagCheckPlug do
  @moduledoc """
  plug(PlausibleWeb.Plugs.FeatureFlagCheckPlug, [:flag_foo, :flag_bar])
  to halt any API connections with 404 where conn.assigns.current_user or conn.assigns.site
  don't have both feature flags true.
  """
  def init(feature_flags) when is_list(feature_flags) and length(feature_flags) > 0 do
    feature_flags
  end

  def init(_),
    do: raise(ArgumentError, "The first argument must be a non-empty list of feature flags")

  def call(%Plug.Conn{} = conn, flags) do
    if validate(conn.assigns.current_user, conn.assigns.site, flags) do
      conn
    else
      PlausibleWeb.Api.Helpers.not_found(conn, "Not found")
    end
  end

  defp validate(current_user, site, flags),
    do:
      Enum.all?(flags, fn flag ->
        FunWithFlags.enabled?(flag, for: current_user) ||
          FunWithFlags.enabled?(flag, for: site)
      end)
end
