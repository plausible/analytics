defmodule Plausible.Stats.Filters.Validations do
  @moduledoc """
  Validations for parsed filter trees that every stats query type shares.
  """

  alias Plausible.Stats.{Filters, QueryError}

  @pattern_filter_operators [:matches, :matches_not, :matches_wildcard, :matches_wildcard_not]
  def validate_case_sensitive_modifier(filters) do
    invalid_filter =
      filters
      |> Filters.all_leaf_filters()
      |> Enum.find(fn filter ->
        case filter do
          [operator, _, _, modifiers] when operator in @pattern_filter_operators ->
            is_map_key(modifiers, :case_sensitive)

          _ ->
            false
        end
      end)

    if invalid_filter do
      {:error,
       %QueryError{
         code: :invalid_filters,
         message:
           "Invalid filters. The case_sensitive modifier is not allowed with pattern operators (#{i(invalid_filter)})"
       }}
    else
      :ok
    end
  end

  @only_toplevel ["event:goal", "event:hostname"]
  def validate_toplevel_only(filters) do
    not_toplevel =
      filters
      |> Filters.dimensions_used_in_filters(min_depth: 1, behavioral_filters: :ignore)
      |> Enum.filter(&(&1 in @only_toplevel))

    if not_toplevel != [] do
      {:error,
       %QueryError{
         code: :invalid_filters,
         message:
           "Invalid filters. Dimension `#{List.first(not_toplevel)}` can only be filtered at the top level."
       }}
    else
      :ok
    end
  end

  def validate_behavioral(filters) do
    filters
    |> Filters.traverse(0, fn behavioral_depth, operator ->
      if operator in [:has_done, :has_not_done] do
        behavioral_depth + 1
      else
        behavioral_depth
      end
    end)
    |> Enum.reduce_while(:ok, fn {[_operator, dimension | _rest], behavioral_depth}, :ok ->
      cond do
        behavioral_depth == 0 ->
          # ignore non-behavioral filters
          {:cont, :ok}

        behavioral_depth > 1 ->
          {:halt,
           {:error,
            %QueryError{
              code: :invalid_filters,
              message:
                "Invalid filters. Behavioral filters (has_done, has_not_done) cannot be nested."
            }}}

        not String.starts_with?(dimension, "event:") ->
          {:halt,
           {:error,
            %QueryError{
              code: :invalid_filters,
              message:
                "Invalid filters. Behavioral filters (has_done, has_not_done) can only be used with event dimension filters."
            }}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  @doc """
  Checks that every custom property used in `filters` is in `allowed_props`,
  as returned by `Plausible.Props.allowed_for/2`.
  """
  def validate_custom_props_access(_filters, :all), do: :ok

  def validate_custom_props_access(filters, allowed_props) do
    valid? =
      filters
      |> Filters.dimensions_used_in_filters()
      |> Enum.all?(fn
        "event:props:" <> prop -> prop in allowed_props
        _ -> true
      end)

    if valid?, do: :ok, else: {:error, custom_props_access_error()}
  end

  def custom_props_access_error() do
    %QueryError{
      code: :feature_access,
      message: "The owner of this site does not have access to the custom properties feature."
    }
  end

  defp i(value), do: inspect(value, charlists: :as_lists)
end
