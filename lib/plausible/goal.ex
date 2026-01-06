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

    field :custom_props, :map, default: %{}

    belongs_to :site, Plausible.Site

    timestamps()
  end

  @fields [
            :id,
            :site_id,
            :event_name,
            :page_path,
            :scroll_threshold,
            :display_name,
            :custom_props
          ] ++
            on_ee(do: [:currency], else: [])

  @max_event_name_length 120

  def max_event_name_length(), do: @max_event_name_length

  @max_custom_props_per_goal 3

  def max_custom_props_per_goal(), do: @max_custom_props_per_goal

  def changeset(goal, attrs \\ %{}) do
    goal
    |> cast(attrs, @fields)
    |> validate_required([:site_id])
    |> cast_assoc(:site)
    |> update_leading_slash()
    |> validate_event_name_and_page_path()
    |> validate_page_path_for_scroll_goal()
    |> maybe_put_display_name()
    |> validate_change(:custom_props, &validate_custom_props/2)
    |> unique_constraint(:display_name, name: :goals_display_name_unique)
    |> unique_constraint(:event_name, name: :goals_event_config_unique)
    |> unique_constraint([:page_path, :scroll_threshold],
      name: :goals_pageview_config_unique
    )
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

  @spec type(t()) :: :event | :scroll | :page
  def type(goal) do
    cond do
      is_binary(goal.event_name) -> :event
      is_binary(goal.page_path) && goal.scroll_threshold > -1 -> :scroll
      is_binary(goal.page_path) -> :page
    end
  end

  @spec has_custom_props?(t()) :: boolean()
  def has_custom_props?(%__MODULE__{custom_props: custom_props})
      when map_size(custom_props) > 0 do
    true
  end

  def has_custom_props?(_), do: false

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

  defp validate_page_path_for_scroll_goal(changeset) do
    scroll_threshold = get_field(changeset, :scroll_threshold)
    page_path = get_field(changeset, :page_path)

    if scroll_threshold > -1 and is_nil(page_path) do
      changeset
      |> add_error(:scroll_threshold, "page_path field missing for page scroll goal")
    else
      changeset
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
      value == "engagement" ->
        {:error, "The event name 'engagement' is reserved and cannot be used as a goal"}

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

  defp validate_custom_props(:custom_props, custom_props) when is_map(custom_props) do
    cond do
      map_size(custom_props) > @max_custom_props_per_goal ->
        [custom_props: "use at most #{@max_custom_props_per_goal} properties per goal"]

      not Enum.all?(custom_props, fn {k, v} ->
        is_binary(k) and is_binary(v)
      end) ->
        [custom_props: "must be a map with string keys and string values"]

      Enum.any?(custom_props, fn {k, _v} ->
        String.length(k) not in 1..Plausible.Props.max_prop_key_length()
      end) ->
        [
          custom_props: "key length is 1..#{Plausible.Props.max_prop_key_length()} characters"
        ]

      Enum.any?(custom_props, fn {_k, v} ->
        String.length(v) not in 1..Plausible.Props.max_prop_value_length()
      end) ->
        [
          custom_props: "value length is 1..#{Plausible.Props.max_prop_value_length()} characters"
        ]

      true ->
        []
    end
  end
end

defimpl Jason.Encoder, for: Plausible.Goal do
  def encode(value, opts) do
    domain = value.site.domain

    value
    |> Map.put(:goal_type, Plausible.Goal.type(value))
    |> Map.take([:id, :goal_type, :event_name, :page_path, :custom_props])
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
