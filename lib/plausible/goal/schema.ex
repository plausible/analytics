defmodule Plausible.Goal do
  use Plausible
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  schema "goals" do
    field :event_name, :string
    field :page_path, :string

    on_full_build do
      field :currency, Ecto.Enum, values: Money.Currency.known_current_currencies()
      many_to_many :funnels, Plausible.Funnel, join_through: Plausible.Funnel.Step
    else
      field :currency, :string, virtual: true, default: nil
      field :funnels, {:array, :map}, virtual: true, default: []
    end

    belongs_to :site, Plausible.Site

    timestamps()
  end

  @fields [:id, :site_id, :event_name, :page_path] ++ on_full_build(do: [:currency], else: [])

  def changeset(goal, attrs \\ %{}) do
    goal
    |> cast(attrs, @fields)
    |> validate_required([:site_id])
    |> cast_assoc(:site)
    |> update_leading_slash()
    |> validate_event_name_and_page_path()
    |> update_change(:event_name, &String.trim/1)
    |> update_change(:page_path, &String.trim/1)
    |> unique_constraint(:event_name, name: :goals_event_name_unique)
    |> unique_constraint(:page_path, name: :goals_page_path_unique)
    |> validate_length(:event_name, max: 120)
    |> check_constraint(:event_name,
      name: :check_event_name_or_page_path,
      message: "cannot co-exist with page_path"
    )
    |> maybe_drop_currency()
  end

  defp update_leading_slash(changeset) do
    case get_field(changeset, :page_path) do
      "/" <> _ ->
        changeset

      page_path when is_binary(page_path) ->
        put_change(changeset, :page_path, "/" <> page_path)

      _ ->
        changeset
    end
  end

  defp validate_event_name_and_page_path(changeset) do
    if validate_page_path(changeset) || validate_event_name(changeset) do
      changeset
    else
      changeset
      |> add_error(:event_name, "this field is required and cannot be blank")
      |> add_error(:page_path, "this field is required and must start with a /")
    end
  end

  defp validate_page_path(changeset) do
    value = get_field(changeset, :page_path)
    value && String.match?(value, ~r/^\/.*/)
  end

  defp validate_event_name(changeset) do
    value = get_field(changeset, :event_name)
    value && String.match?(value, ~r/^.+/)
  end

  defp maybe_drop_currency(changeset) do
    if full_build?() and get_field(changeset, :page_path) do
      delete_change(changeset, :currency)
    else
      changeset
    end
  end
end

defimpl Jason.Encoder, for: Plausible.Goal do
  def encode(value, opts) do
    goal_type =
      cond do
        value.event_name -> :event
        value.page_path -> :page
      end

    domain = value.site.domain

    value
    |> Map.put(:goal_type, goal_type)
    |> Map.take([:id, :goal_type, :event_name, :page_path])
    |> Map.put(:domain, domain)
    |> Jason.Encode.map(opts)
  end
end

defimpl String.Chars, for: Plausible.Goal do
  def to_string(%{page_path: page_path}) when is_binary(page_path) do
    "Visit " <> page_path
  end

  def to_string(%{event_name: name, currency: nil}) when is_binary(name) do
    name
  end

  def to_string(%{event_name: name, currency: currency}) when is_binary(name) do
    name <> " (#{currency})"
  end
end

defimpl Phoenix.HTML.Safe, for: Plausible.Goal do
  def to_iodata(data) do
    data |> to_string() |> Phoenix.HTML.Engine.html_escape()
  end
end
