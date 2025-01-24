defmodule Plausible.Goal do
  use Plausible
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  schema "goals" do
    field :event_name, :string
    field :page_path, :string
    field :scroll_threshold, :integer, default: -1
    field :display_name, :string

    on_ee do
      field :currency, Ecto.Enum, values: Money.Currency.known_current_currencies()
      many_to_many :funnels, Plausible.Funnel, join_through: Plausible.Funnel.Step
    else
      field :currency, :string, virtual: true, default: nil
      field :funnels, {:array, :map}, virtual: true, default: []
    end

    belongs_to :site, Plausible.Site

    timestamps()
  end

  @fields [:id, :site_id, :event_name, :page_path, :scroll_threshold, :display_name] ++
            on_ee(do: [:currency], else: [])

  @max_event_name_length 120

  def max_event_name_length(), do: @max_event_name_length

  def changeset(goal, attrs \\ %{}) do
    goal
    |> cast(attrs, @fields)
    |> validate_required([:site_id])
    |> cast_assoc(:site)
    |> update_leading_slash()
    |> validate_event_name_and_page_path()
    |> maybe_put_display_name()
    |> unique_constraint(:event_name, name: :goals_event_name_unique)
    |> unique_constraint([:page_path, :scroll_threshold],
      name: :goals_page_path_and_scroll_threshold_unique
    )
    |> unique_constraint(:display_name, name: :goals_site_id_display_name_index)
    |> validate_length(:event_name, max: @max_event_name_length)
    |> validate_number(:scroll_threshold,
      greater_than_or_equal_to: -1,
      less_than_or_equal_to: 100,
      message: "Should be -1 (missing) or in range [0, 100]"
    )
    |> check_constraint(:event_name,
      name: :check_event_name_or_page_path,
      message: "cannot co-exist with page_path"
    )
    |> maybe_drop_currency()
  end

  @spec display_name(t()) :: String.t()
  def display_name(goal) do
    goal.display_name
  end

  @spec type(t()) :: :event | :page
  def type(%{event_name: event_name}) when is_binary(event_name), do: :event
  def type(%{page_path: page_path}) when is_binary(page_path), do: :page

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
    case {validate_page_path(changeset), validate_event_name(changeset)} do
      {:ok, _} ->
        update_change(changeset, :page_path, &String.trim/1)

      {_, :ok} ->
        update_change(changeset, :event_name, &String.trim/1)

      {{:error, page_path_error}, {:error, event_name_error}} ->
        changeset
        |> add_error(:event_name, event_name_error)
        |> add_error(:page_path, page_path_error)
    end
  end

  defp validate_page_path(changeset) do
    value = get_field(changeset, :page_path)

    if value && String.match?(value, ~r/^\/.*/) do
      :ok
    else
      {:error, "this field is required and must start with a /"}
    end
  end

  defp validate_event_name(changeset) do
    value = get_field(changeset, :event_name)

    cond do
      value == "pageleave" ->
        {:error, "The event name 'pageleave' is reserved and cannot be used as a goal"}

      value && String.match?(value, ~r/^.+/) ->
        :ok

      true ->
        {:error, "this field is required and cannot be blank"}
    end
  end

  defp maybe_drop_currency(changeset) do
    if ee?() and get_field(changeset, :page_path) do
      delete_change(changeset, :currency)
    else
      changeset
    end
  end

  defp maybe_put_display_name(changeset) do
    clause =
      Enum.map([:display_name, :page_path, :event_name], &get_field(changeset, &1))

    case clause do
      [nil, path, _] when is_binary(path) ->
        put_change(changeset, :display_name, "Visit " <> path)

      [nil, _, event_name] when is_binary(event_name) ->
        put_change(changeset, :display_name, event_name)

      _ ->
        changeset
    end
    |> update_change(:display_name, &String.trim/1)
    |> validate_required(:display_name)
  end
end

defimpl Jason.Encoder, for: Plausible.Goal do
  def encode(value, opts) do
    domain = value.site.domain

    value
    |> Map.put(:goal_type, Plausible.Goal.type(value))
    |> Map.take([:id, :goal_type, :event_name, :page_path])
    |> Map.put(:domain, domain)
    |> Map.put(:display_name, value.display_name)
    |> Jason.Encode.map(opts)
  end
end

defimpl String.Chars, for: Plausible.Goal do
  def to_string(goal) do
    goal.display_name
  end
end

defimpl Phoenix.HTML.Safe, for: Plausible.Goal do
  def to_iodata(data) do
    data |> to_string() |> Phoenix.HTML.Engine.html_escape()
  end
end
