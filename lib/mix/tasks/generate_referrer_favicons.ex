defmodule Mix.Tasks.GenerateReferrerFavicons do
  use Mix.Task
  use Plausible.Repo
  require Logger

  @dialyzer {:nowarn_function, run: 1}
  # coveralls-ignore-start

  def run(_) do
    entries =
      :yamerl_constr.file(Application.app_dir(:plausible, "priv/ref_inspector/referers.yml"))
      |> List.first()
      |> Enum.map(fn {_key, val} -> val end)
      |> Enum.concat()

    domains =
      Enum.reduce(entries, %{}, fn {key, val}, domains ->
        domain =
          Enum.into(val, %{})[~c"domains"]
          |> List.first()

        Map.put_new(domains, List.to_string(key), List.to_string(domain))
      end)

    File.write!(
      Application.app_dir(:plausible, "priv/referer_favicon_domains.json"),
      Jason.encode!(domains)
    )
  end
end
