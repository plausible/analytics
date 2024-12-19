defmodule Plausible.Permissions do
  @moduledoc """
    This module defines granular permissions for possible Plausible roles
    and provides functions to trim down these permissions by
    * site and/or user feature flags (see Plausible.FeatureFlags)
    * team subscription billing features (see Plausible.Billing.Feature)
    * site options (whether owners have disabled the feature on site)
  """
  @public_permissions [Plausible.Permissions.Segments.Site.List]
  @viewer_permissions @public_permissions ++
                        [
                          Plausible.Permissions.Segments.ViewSegmentData,
                          Plausible.Permissions.Segments.Personal.List,
                          Plausible.Permissions.Segments.Personal.Create,
                          Plausible.Permissions.Segments.Personal.Update,
                          Plausible.Permissions.Segments.Personal.Delete
                        ]
  @editor_permissions @viewer_permissions ++
                        [
                          Plausible.Permissions.Segments.Site.List,
                          Plausible.Permissions.Segments.Site.Create,
                          Plausible.Permissions.Segments.Site.Update,
                          Plausible.Permissions.Segments.Site.Delete
                        ]
  @owner_permissions @editor_permissions
  @super_admin_permissions @owner_permissions

  @permissions_by_role %{
    public: @public_permissions,
    viewer: @viewer_permissions,
    editor: @editor_permissions,
    owner: @owner_permissions,
    super_admin: @super_admin_permissions
  }

  def get_filtered_for_role(role), do: @permissions_by_role[role]

  def filter_permissions_by_feature_flags(permissions, feature_flags_map),
    do:
      permissions
      |> Enum.filter(fn p ->
        governed_by_feature_flag = p.governed_by_feature_flag()

        if is_nil(governed_by_feature_flag),
          do: true,
          else: feature_flags_map[governed_by_feature_flag]
      end)

  def filter_permissions_by_billing_features(permissions, billing_features_map),
    do:
      permissions
      |> Enum.filter(fn p ->
        governed_by_billing_feature = p.governed_by_billing_feature()

        if is_nil(governed_by_billing_feature),
          do: true,
          else: billing_features_map[governed_by_billing_feature]
      end)

  def filter_permissions_by_site_options(permissions, site_options_map),
    do:
      permissions
      |> Enum.filter(fn p ->
        governed_by_site_option = p.governed_by_site_option()

        if is_nil(governed_by_site_option),
          do: true,
          else: site_options_map[governed_by_site_option]
      end)

  defmacro __using__(opts \\ []) do
    quote location: :keep do
      def name, do: Keyword.get(unquote(opts), :name)

      def governed_by_feature_flag, do: Keyword.get(unquote(opts), :governed_by_feature_flag)

      def governed_by_billing_feature,
        do: Keyword.get(unquote(opts), :governed_by_billing_feature)

      def governed_by_site_option, do: Keyword.get(unquote(opts), :governed_by_site_option)
    end
  end
end

# credo:disable-for-lines:10000 Credo.Check.Readability.ModuleDoc
defmodule Plausible.Permissions.Segments.ViewSegmentData,
  do:
    use(Plausible.Permissions,
      name: "view segment data",
      governed_by_feature_flag: :saved_segments
    )

defmodule Plausible.Permissions.Segments.Personal.List,
  do:
    use(Plausible.Permissions,
      name: "list personal segments",
      governed_by_feature_flag: :saved_segments
    )

defmodule Plausible.Permissions.Segments.Personal.Create,
  do:
    use(Plausible.Permissions,
      name: "create personal segments",
      governed_by_feature_flag: :saved_segments
    )

defmodule Plausible.Permissions.Segments.Personal.Update,
  do:
    use(Plausible.Permissions,
      name: "update personal segments",
      governed_by_feature_flag: :saved_segments
    )

defmodule Plausible.Permissions.Segments.Personal.Delete,
  do:
    use(Plausible.Permissions,
      name: "delete personal segments",
      governed_by_feature_flag: :saved_segments
    )

defmodule Plausible.Permissions.Segments.Site.List,
  do:
    use(Plausible.Permissions,
      name: "list site segments",
      governed_by_feature_flag: :saved_segments,
      governed_by_billing_feature: Plausible.Billing.Feature.Props
    )

defmodule Plausible.Permissions.Segments.Site.Create,
  do:
    use(Plausible.Permissions,
      name: "create site segments",
      governed_by_feature_flag: :saved_segments,
      governed_by_billing_feature: Plausible.Billing.Feature.Props
    )

defmodule Plausible.Permissions.Segments.Site.Update,
  do:
    use(Plausible.Permissions,
      name: "update site segments",
      governed_by_feature_flag: :saved_segments,
      governed_by_billing_feature: Plausible.Billing.Feature.Props
    )

defmodule Plausible.Permissions.Segments.Site.Delete,
  do:
    use(Plausible.Permissions,
      name: "delete site segments",
      governed_by_feature_flag: :saved_segments,
      governed_by_billing_feature: Plausible.Billing.Feature.Props
    )
