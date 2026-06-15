defmodule Plausible.Auth.TOTP.FallbackEncryptedBinary do
  @moduledoc """
  Defines an Ecto type so Cloak.Ecto can encrypt/decrypt a binary field.

  Used for fallback vault field.
  """

  use Cloak.Ecto.Binary, vault: Plausible.Auth.TOTP.FallbackVault
end
