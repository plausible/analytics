defmodule Plausible.Auth.TOTP.FallbackVault do
  @moduledoc """
  Provides a fallback vault that will be used to encrypt/decrypt the TOTP 
  secrets of users who enable it in case the primary vault fails.
  """

  use Cloak.Vault, otp_app: :plausible

  @impl GenServer
  def init(config) do
    {key, config} = Keyword.pop!(config, :key)

    config =
      Keyword.put(config, :ciphers,
        default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", iv_length: 12, key: key}
      )

    {:ok, config}
  end
end
