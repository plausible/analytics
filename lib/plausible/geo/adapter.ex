defmodule Plausible.Geo.Adapter do
  @moduledoc "Behaviour to be implemented by geolocation adapters"

  @type entry :: map
  @type opts :: Keyword.t()
  @type ip_address :: :inet.ip_address() | String.t()

  @callback load_db(opts) :: :ok
  @callback database_type :: String.t() | nil
  @callback lookup(ip_address) :: entry | nil
end
