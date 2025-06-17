defmodule Plausible.Auth.SSO.Domain.Status do
  @moduledoc false

  defmacro __using__(opts) do
    as = Keyword.get(opts, :as, Status)

    quote do
      require Plausible.Auth.SSO.Domain.Status
      alias Plausible.Auth.SSO.Domain.Status, as: unquote(as)
    end
  end

  defmacro pending(), do: :pending
  defmacro in_progress(), do: :in_progress
  defmacro verified(), do: :verified
  defmacro unverified(), do: :unverified

  defmacro all() do
    [pending(), in_progress(), verified(), unverified()]
  end
end
