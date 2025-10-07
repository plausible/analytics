defmodule PlausibleWeb.Plugs.SecureEmbedHeaders do
  @moduledoc """
  Sets secure headers tailored for embedded content.
  """

  import Plug.Conn

  def init(_opts) do
    []
  end

  def call(conn, _opts) do
    merge_resp_headers(
      conn,
      [
        {"referrer-policy", "strict-origin-when-cross-origin"},
        {"x-content-type-options", "nosniff"},
        {"x-permitted-cross-domain-policies", "none"}
      ]
    )
  end
end
