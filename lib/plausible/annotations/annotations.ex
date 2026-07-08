defmodule Plausible.Annotations do
  @moduledoc """
  Module for accessing Annotations.
  """
  alias Plausible.Annotations.Annotation
  alias Plausible.Auth.User
  alias Plausible.Repo
  alias Plausible.Stats.DateTimeRange
  import Ecto.Query

  @roles_with_personal_annotations [:billing, :viewer, :editor, :admin, :owner, :super_admin]
  @roles_with_maybe_site_annotations [:editor, :admin, :owner, :super_admin]

  @type error_not_enough_permissions() :: :not_enough_permissions
  @type error_annotation_not_found() :: :annotation_not_found
  @type error_annotation_limit_reached() :: :annotations_limit_reached
  @type error_invalid_annotation() :: {:invalid_annotation, Keyword.t()}

  @max_annotations 500

  @spec roles_with_personal_annotations() :: [atom()]
  def roles_with_personal_annotations(), do: @roles_with_personal_annotations

  @spec roles_with_maybe_site_annotations() :: [atom()]
  def roles_with_maybe_site_annotations(), do: @roles_with_maybe_site_annotations

  @spec site_annotations_available?(Plausible.Site.t()) :: boolean()
  def site_annotations_available?(site),
    # this feature is bundled with SiteSegments
    do: Plausible.Billing.Feature.SiteSegments.check_availability(site.team) == :ok

  @spec get_all_for_site(Plausible.Site.t(), atom(), User.t() | nil, DateTimeRange.t()) ::
          {:error, error_not_enough_permissions()} | {:ok, list(Annotation.t())}
  def get_all_for_site(site, site_role, user, range_in_site_tz) do
    fields = [:id, :note, :type, :datetime, :granularity, :site_id, :inserted_at, :updated_at]

    cond do
      site_role in [:public] ->
        annotations =
          Repo.all(
            from(annotation in Annotation,
              inner_join: site in assoc(annotation, :site),
              select: ^fields,
              where: annotation.site_id == ^site.id,
              where: annotation.type == :site,
              order_by: [desc: annotation.updated_at, desc: annotation.id],
              preload: [site: site]
            )
            |> filter_by_range(range_in_site_tz)
          )

        {:ok, annotations}

      site_role in roles_with_personal_annotations() or
          site_role in roles_with_maybe_site_annotations() ->
        fields = fields ++ [:owner_id]

        annotations =
          Repo.all(
            from(annotation in Annotation,
              inner_join: site in assoc(annotation, :site),
              left_join: owner in assoc(annotation, :owner),
              select: ^fields,
              where: annotation.site_id == ^site.id,
              where:
                annotation.type == :site or
                  (annotation.type == :personal and annotation.owner_id == ^user.id),
              order_by: [desc: annotation.updated_at, desc: annotation.id],
              preload: [site: site, owner: owner]
            )
            |> filter_by_range(range_in_site_tz)
          )

        {:ok, annotations}

      true ->
        {:error, :not_enough_permissions}
    end
  end

  @spec get_one(User.t() | nil, Plausible.Site.t(), atom(), pos_integer() | nil) ::
          {:ok, Annotation.t()}
          | {:error, error_not_enough_permissions() | error_annotation_not_found()}
  def get_one(nil, _site, _site_role, _annotation_id) do
    {:error, :not_enough_permissions}
  end

  def get_one(user, site, site_role, annotation_id) do
    if site_role in roles_with_personal_annotations() do
      case do_get_one(user, site, annotation_id) do
        %Annotation{} = annotation -> {:ok, annotation}
        nil -> {:error, :annotation_not_found}
      end
    else
      {:error, :not_enough_permissions}
    end
  end

  @spec insert_one(User.t() | nil, Plausible.Site.t(), atom(), map()) ::
          {:ok, Annotation.t()}
          | {:error,
             error_not_enough_permissions()
             | error_invalid_annotation()
             | error_annotation_limit_reached()}
  def insert_one(nil, _site, _site_role, _params) do
    {:error, :not_enough_permissions}
  end

  def insert_one(user, site, site_role, params) do
    changeset = Annotation.create_changeset(params, site, user)
    annotation_type = Ecto.Changeset.get_field(changeset, :type)

    with :ok <- can_insert_one?(site, site_role, annotation_type),
         {:ok, annotation} <- Repo.insert(changeset) do
      {:ok, Repo.preload(annotation, [:site, :owner])}
    else
      {:error, %Ecto.Changeset{errors: errors}} ->
        {:error, {:invalid_annotation, errors}}

      {:error, _type} = error ->
        error
    end
  end

  @spec update_one(User.t() | nil, Plausible.Site.t(), atom(), pos_integer(), map()) ::
          {:ok, Annotation.t()}
          | {:error,
             error_not_enough_permissions()
             | error_invalid_annotation()
             | error_annotation_not_found()}
  def update_one(nil, _site, _site_role, _annotation_id, _params) do
    {:error, :not_enough_permissions}
  end

  def update_one(user, site, site_role, annotation_id, params) do
    with {:ok, annotation} <- get_one(user, site, site_role, annotation_id),
         changeset = Annotation.update_changeset(annotation, params, user),
         new_annotation_type = Ecto.Changeset.get_field(changeset, :type),
         :ok <- can_update_one?(site, site_role, new_annotation_type, annotation.type),
         {:ok, annotation} <- Repo.update(changeset) do
      {:ok, Repo.preload(annotation, [:site, :owner])}
    else
      {:error, %Ecto.Changeset{errors: errors}} ->
        {:error, {:invalid_annotation, errors}}

      {:error, _type} = error ->
        error
    end
  end

  @spec delete_one(User.t() | nil, Plausible.Site.t(), atom(), pos_integer()) ::
          {:ok, Annotation.t()}
          | {:error,
             error_not_enough_permissions()
             | error_annotation_not_found()}
  def delete_one(nil, _site, _site_role, _annotation_id) do
    {:error, :not_enough_permissions}
  end

  def delete_one(user, site, site_role, annotation_id) do
    with {:ok, annotation} <- get_one(user, site, site_role, annotation_id) do
      cond do
        annotation.type == :site and site_role in roles_with_maybe_site_annotations() ->
          {:ok, do_delete_one(annotation)}

        annotation.type == :personal and site_role in roles_with_personal_annotations() ->
          {:ok, do_delete_one(annotation)}

        true ->
          {:error, :not_enough_permissions}
      end
    end
  end

  @spec after_user_removed_from_site(Plausible.Site.t(), User.t()) :: :ok
  def after_user_removed_from_site(site, user) do
    Repo.delete_all(
      from(annotation in Annotation,
        where: annotation.site_id == ^site.id,
        where: annotation.owner_id == ^user.id,
        where: annotation.type == :personal
      )
    )

    Repo.update_all(
      from(annotation in Annotation,
        where: annotation.site_id == ^site.id,
        where: annotation.owner_id == ^user.id,
        where: annotation.type == :site,
        update: [set: [owner_id: nil]]
      ),
      []
    )

    :ok
  end

  @spec after_user_removed_from_team(Plausible.Teams.Team.t(), User.t()) :: :ok
  def after_user_removed_from_team(team, user) do
    team_sites_q =
      from(
        site in Plausible.Site,
        where: site.team_id == ^team.id,
        where: parent_as(:annotation).site_id == site.id
      )

    Repo.delete_all(
      from(annotation in Annotation,
        as: :annotation,
        where: annotation.owner_id == ^user.id,
        where: annotation.type == :personal,
        where: exists(team_sites_q)
      )
    )

    Repo.update_all(
      from(annotation in Annotation,
        as: :annotation,
        where: annotation.owner_id == ^user.id,
        where: annotation.type == :site,
        where: exists(team_sites_q),
        update: [set: [owner_id: nil]]
      ),
      []
    )

    :ok
  end

  @spec user_removed(User.t()) :: :ok
  def user_removed(user) do
    Repo.delete_all(
      from(annotation in Annotation,
        as: :annotation,
        where: annotation.owner_id == ^user.id,
        where: annotation.type == :personal
      )
    )

    #  Site annotations are set to owner=null via ON DELETE SET NULL

    :ok
  end

  defp filter_by_range(query, range_in_site_tz) do
    # Minute granularity annotations are stored for the particular UTC moment they're for,
    # so they must be in the range of the UTC query period.
    minute_granularity_range =
      range_in_site_tz |> DateTimeRange.to_timezone("Etc/UTC")

    # Date granularity annotations are stored for the UTC midnight of the date they're for,
    # so the range for querying these must reflect that.
    [date_granularity_range_first, date_granularity_range_last] =
      [range_in_site_tz.first, range_in_site_tz.last]
      |> Enum.map(fn utc_datetime ->
        utc_datetime |> DateTime.to_date() |> Annotation.serialize_date_granularity_datetime()
      end)

    from(annotation in query,
      where:
        (annotation.granularity == :minute and
           annotation.datetime >= ^minute_granularity_range.first and
           annotation.datetime <= ^minute_granularity_range.last) or
          (annotation.granularity == :date and
             annotation.datetime >=
               ^date_granularity_range_first and
             annotation.datetime <=
               ^date_granularity_range_last)
    )
  end

  defp do_get_one(user, site, annotation_id)

  defp do_get_one(_user, _site, nil) do
    nil
  end

  defp do_get_one(user, site, annotation_id) do
    query =
      from(annotation in Annotation,
        where: annotation.site_id == ^site.id,
        where: annotation.id == ^annotation_id,
        where:
          annotation.type == :site or
            (annotation.type == :personal and annotation.owner_id == ^user.id),
        preload: [:site, :owner]
      )

    Repo.one(query)
  end

  defp do_delete_one(annotation) do
    annotation
    |> Repo.preload([:site, :owner])
    |> Repo.delete!()
  end

  defp can_update_one?(site, site_role, new_annotation_type, existing_annotation_type) do
    updating_to_site_annotation? = new_annotation_type == :site
    updating_to_personal_annotation? = new_annotation_type == :personal

    cond do
      (existing_annotation_type == :site or
         updating_to_site_annotation?) and site_role in roles_with_maybe_site_annotations() and
          site_annotations_available?(site) ->
        :ok

      # Allow demoting a site annotation to personal even when
      # site_annotations is no longer available on the plan — gives users a
      # way to keep their annotations usable after a downgrade.
      existing_annotation_type == :site and updating_to_personal_annotation? and
          site_role in roles_with_maybe_site_annotations() ->
        :ok

      existing_annotation_type == :personal and updating_to_personal_annotation? and
          site_role in roles_with_personal_annotations() ->
        :ok

      true ->
        {:error, :not_enough_permissions}
    end
  end

  defp can_insert_one?(site, site_role, annotation_type) do
    cond do
      count_annotations(site.id) >= @max_annotations ->
        {:error, :annotations_limit_reached}

      annotation_type == :site and site_role in roles_with_maybe_site_annotations() and
          site_annotations_available?(site) ->
        :ok

      annotation_type == :personal and
          site_role in roles_with_personal_annotations() ->
        :ok

      true ->
        {:error, :not_enough_permissions}
    end
  end

  defp count_annotations(site_id) do
    from(annotation in Annotation,
      where: annotation.site_id == ^site_id
    )
    |> Repo.aggregate(:count, :id)
  end
end
