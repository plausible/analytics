defmodule Plausible.Shield.PageRule do
  @moduledoc """
  Schema for Pages block list
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "shield_rules_page" do
    belongs_to :site, Plausible.Site
    field :page_path, :string
    field :page_path_pattern, Plausible.Ecto.Types.CompiledRegex
    field :action, Ecto.Enum, values: [:deny, :allow], default: :deny
    field :added_by, :string

    # If `from_cache?` is set, the struct might be incomplete - see `Plausible.Site.Shield.Rules.IP.Cache`
    field :from_cache?, :boolean, virtual: true, default: false
    timestamps()
  end

  def changeset(rule \\ %__MODULE__{}, attrs) do
    rule
    |> cast(attrs, [:site_id, :page_path])
    |> validate_required([:site_id, :page_path])
    |> validate_length(:page_path, max: 250)
    |> validate_change(:page_path, fn :page_path, p ->
      if not String.starts_with?(p, "/") do
        [page_path: "must start with /"]
      else
        []
      end
    end)
    |> store_regex()
    |> unique_constraint(:page_path_pattern,
      name: :shield_rules_page_site_id_page_path_pattern_index,
      error_key: :page_path,
      message: "rule already exists"
    )
  end

  defp store_regex(changeset) do
    case get_field(changeset, :page_path) do
      "/" <> _ = page_path ->
        regex =
          page_path
          |> Regex.escape()
          |> String.replace("\\*\\*", ".*")
          |> String.replace("\\*", ".*")

        regex = "^#{regex}$"

        verify_valid_regex(changeset, regex)

      _ ->
        changeset
    end
  end

  defp verify_valid_regex(changeset, regex) do
    case Regex.compile(regex) do
      {:ok, _} ->
        put_change(changeset, :page_path_pattern, regex)

      {:error, _} ->
        add_error(changeset, :page_path, "could not compile regular expression")
    end
  end
end
