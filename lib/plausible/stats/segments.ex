defmodule Plausible.Stats.Segments do
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

  # spec doesn't work / doesn't help
  @spec get_permissions_whitelist(site :: Plausible.Site.t()) :: list(permission())
  def get_permissions_whitelist(site) do
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

  # spec doesn't work / doesn't help
  @spec has_permission(%{permission() => true}, permission()) :: any()
  defguard has_permission(permissions, permission)
           when is_map(permissions) and is_map_key(permissions, permission)
end
