defmodule Plausible.Auth.TOTP.EncryptedBinary do
  @moduledoc """
  Defines an Ecto type so Cloak.Ecto can encrypt/decrypt a binary field.
  """

  use Cloak.Ecto.Binary, vault: Plausible.Auth.TOTP.Vault
end
