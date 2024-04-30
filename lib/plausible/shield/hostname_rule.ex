defmodule Plausible.Shield.HostnameRule do
  @moduledoc """
  Schema for Hostnames allow list
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "shield_rules_hostname" do
    belongs_to :site, Plausible.Site
    field :hostname, :string
    field :hostname_pattern, Plausible.Ecto.Types.CompiledRegex
    field :action, Ecto.Enum, values: [:deny, :allow], default: :allow
    field :added_by, :string

    # If `from_cache?` is set, the struct might be incomplete - see `Plausible.Site.Shield.Rules.IP.Cache`
    field :from_cache?, :boolean, virtual: true, default: false
    timestamps()
  end

  def changeset(rule \\ %__MODULE__{}, attrs) do
    rule
    |> cast(attrs, [:site_id, :hostname])
    |> validate_required([:site_id, :hostname])
    |> validate_length(:hostname, max: 250)
    |> store_regex()
    |> unique_constraint(:hostname_pattern,
      name: :shield_rules_hostname_site_id_hostname_pattern_index,
      error_key: :hostname,
      message: "rule already exists"
    )
  end

  defp store_regex(changeset) do
    case fetch_change(changeset, :hostname) do
      {:ok, hostname} ->
        hostname
        |> build_regex()
        |> verify_and_put_regex(changeset)

      :error ->
        changeset
    end
  end

  defp build_regex(hostname) do
    regex =
      hostname
      |> Regex.escape()
      |> String.replace("\\*\\*", ".*")
      |> String.replace("\\*", ".*")

    "^#{regex}$"
  end

  defp verify_and_put_regex(regex, changeset) do
    case Regex.compile(regex) do
      {:ok, _} ->
        put_change(changeset, :hostname_pattern, regex)

      {:error, _} ->
        add_error(changeset, :hostname, "could not compile regular expression")
    end
  end
end
