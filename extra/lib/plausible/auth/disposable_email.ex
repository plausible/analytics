defmodule Plausible.Auth.DisposableEmail do
  @moduledoc """
  Detects email addresses on disposable (throwaway) email domains.

  Uses the list from https://github.com/castle/disposable-email-domains,
  vendored at `priv/disposable_email_domains.txt` (one domain per line, MIT licensed).
  The list is read at compile time, so refreshing it needs a recompile:

      curl -fsSL -o priv/disposable_email_domains.txt \\
        https://raw.githubusercontent.com/castle/disposable-email-domains/master/disposable-email-domains.txt

  `:extra_domains` in this module's config are matched too, at compile time. Tests
  use it for domains that no real list contains, see `config/test.exs`.

  Only the exact domain of the address is matched, not its parent domains.

  Call `Plausible.Auth.disposable_email?/1` instead of this module directly: it is
  also available (always `false`) on Community Edition.
  """

  @domains_path "priv/disposable_email_domains.txt"
  @external_resource @domains_path
  @domains Application.app_dir(:plausible, @domains_path)
           |> File.read!()
           |> String.split("\n", trim: true)
           |> Enum.concat(Application.compile_env(:plausible, [__MODULE__, :extra_domains], []))
           |> MapSet.new()

  @doc false
  def domains_count, do: MapSet.size(@domains)

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
    |> to_ascii()
  end

  defp to_ascii(domain) do
    domain
    |> String.to_charlist()
    |> :idna.encode(uts46: true)
    |> to_string()
  catch
    :exit, _reason -> domain
  end
end
