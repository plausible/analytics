defmodule Plausible.Stats.Segments do
  @moduledoc """
    This module contains functions for
    - validating segment related permissions
    - validating segment data
  """

  @permissions [
    :can_see_segment_data,
    :can_create_personal_segments,
    :can_list_personal_segments,
    :can_edit_personal_segments,
    :can_delete_personal_segments,
    :can_create_site_segments,
    :can_list_site_segments,
    :can_edit_site_segments,
    :can_delete_site_segments
  ]

  @type permission() :: unquote(Enum.reduce(@permissions, &{:|, [], [&1, &2]}))

  @doc """
  This function maps segment permissions to user roles.

  ## Examples:
      iex> get_role_permissions(:public)
      [:can_list_site_segments]

      iex> get_role_permissions(:viewer)
      [
        :can_list_site_segments,
        :can_see_segment_data,
        :can_create_personal_segments,
        :can_list_personal_segments,
        :can_edit_personal_segments,
        :can_delete_personal_segments
      ]

      iex> get_role_permissions(:editor)
      [
        :can_list_site_segments,
        :can_see_segment_data,
        :can_create_personal_segments,
        :can_list_personal_segments,
        :can_edit_personal_segments,
        :can_delete_personal_segments,
        :can_create_site_segments,
        :can_edit_site_segments,
        :can_delete_site_segments
      ]

      iex> get_role_permissions(:admin) == get_role_permissions(:editor)
      true

      iex> get_role_permissions(:owner) == get_role_permissions(:editor)
      true

      iex> get_role_permissions(:super_admin) == get_role_permissions(:editor)
      true
  """
  @spec get_role_permissions(PlausibleWeb.Plugs.AuthorizeSiteAccess.site_role()) ::
          list(permission())

  def get_role_permissions(role) do
    case role do
      :public ->
        [
          :can_list_site_segments
        ]

      :viewer ->
        get_role_permissions(:public) ++
          [
            :can_see_segment_data,
            :can_create_personal_segments,
            :can_list_personal_segments,
            :can_edit_personal_segments,
            :can_delete_personal_segments
          ]

      :editor ->
        get_role_permissions(:viewer) ++
          [
            :can_create_site_segments,
            :can_edit_site_segments,
            :can_delete_site_segments
          ]

      :admin ->
        get_role_permissions(:editor)

      :owner ->
        get_role_permissions(:editor)

      :super_admin ->
        get_role_permissions(:editor)

      _ ->
        []
    end
  end

  # this spec doesn't work / doesn't help
  @spec get_permissions_whitelist(site :: Plausible.Site.t()) :: list(permission())

  def get_permissions_whitelist(%Plausible.Site{} = site) do
    common_permissions = [
      :can_see_segment_data,
      :can_create_personal_segments,
      :can_list_personal_segments,
      :can_edit_personal_segments,
      :can_delete_personal_segments
    ]

    site_permissions = [
      :can_create_site_segments,
      :can_list_site_segments,
      :can_edit_site_segments,
      :can_delete_site_segments
    ]

    if Plausible.Billing.Feature.Props.check_availability(site.team) == :ok do
      common_permissions ++ site_permissions
    else
      common_permissions
    end
  end

  # this spec doesn't work / doesn't help
  @spec has_permission(%{permission() => true}, permission()) :: any()

  defguard has_permission(permissions, permission)
           when is_map(permissions) and is_map_key(permissions, permission)

  def validate_segment_data_if_exists(%Plausible.Site{} = _site, nil = _segment_data), do: :ok

  def validate_segment_data_if_exists(%Plausible.Site{} = site, segment_data),
    do: validate_segment_data(site, segment_data)

  def validate_segment_data(
        %Plausible.Site{} = site,
        %{"filters" => filters}
      ) do
    case build_naive_query_from_segment_data(site, filters) do
      {:ok, %Plausible.Stats.Query{filters: _filters}} ->
        :ok

      {:error, message} ->
        reformat_filters_errors(message)
    end
  end

  @doc """
    This function builds a simple query using the filters from Plausibe.Segment.segment_data
    to test whether the filters used in the segment stand as legitimate query filters.
    If they don't, it indicates an error with the filters that must be passed to the client,
    so they could reconfigure the filters.
  """
  def build_naive_query_from_segment_data(%Plausible.Site{} = site, filters),
    do:
      Plausible.Stats.Query.build(
        site,
        :internal,
        %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "7d",
          "filters" => filters
        },
        %{}
      )

  @doc """
    This function handles the error from building the naive query that is used to validate segment filters,
    collecting filter related errors into a list.
    If the error is not only about filters, the client can't do anything about the situation,
    and the error message is returned as-is.

    ### Examples
    iex> reformat_filters_errors(~s(#/metrics/0 Invalid metric "Visitors"\\n#/filters/0 Invalid filter "A"))
    {:error, ~s(#/metrics/0 Invalid metric "Visitors"\\n#/filters/0 Invalid filter "A")}

    iex> reformat_filters_errors(~s(#/filters/0 Invalid filter "A"\\n#/filters/1 Invalid filter "B"))
    {:error, [~s(#/filters/0 Invalid filter "A"), ~s(#/filters/1 Invalid filter "B")]}
  """
  def reformat_filters_errors(message) do
    lines = String.split(message, "\n")

    if Enum.all?(lines, fn m -> String.starts_with?(m, "#/filters/") end) do
      {:error, lines}
    else
      {:error, message}
    end
  end
end
