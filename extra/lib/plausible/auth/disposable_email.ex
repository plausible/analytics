defmodule Plausible.Auth.DisposableEmail do
  @moduledoc """
  Detects email addresses on disposable (throwaway) email domains.

  Uses the "normal" list from https://github.com/disposable/disposable,
  vendored at `priv/disposable_email_domains.txt` (one domain per line, MIT licensed).
  The list is read at compile time, so refreshing it needs a recompile:

      curl -fsSL -o priv/disposable_email_domains.txt \\
        https://raw.githubusercontent.com/disposable/disposable-email-domains/master/domains.txt

  The "normal" list only contains domains used for temporary mailboxes. Unlike the
  "strict" list, it does not include freemail providers (Outlook, Hotmail, ...) or
  alias/forwarding services (SimpleLogin, Apple Hide My Email, ...).

  Only the exact domain of the address is matched, not its parent domains.

  This is EE-only (it lives in `extra/lib`): Community Edition does not reject
  disposable addresses.
  """

  @external_resource "priv/disposable_email_domains.txt"
  @domains Application.app_dir(:plausible, "priv/disposable_email_domains.txt")
           |> File.read!()
           |> String.split("\n", trim: true)
           |> MapSet.new()

  @spec disposable?(String.t() | nil) :: boolean()
  def disposable?(email) when is_binary(email) do
    case email |> String.split("@") |> Enum.reverse() do
      [domain, _local | _] -> MapSet.member?(@domains, normalize_domain(domain))
      _ -> false
    end
  end

  def disposable?(_), do: false

  defp normalize_domain(domain) do
    domain
    |> String.trim()
    |> String.trim_trailing(".")
    |> String.downcase()
  end
end
