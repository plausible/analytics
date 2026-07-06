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

  @type error_not_enough_permissions() :: {:error, :not_enough_permissions}
  @type error_annotation_not_found() :: {:error, :annotation_not_found}
  @type error_annotation_limit_reached() :: {:error, :annotations_limit_reached}
  @type error_invalid_annotation() :: {:error, {:invalid_annotation, Keyword.t()}}
  @type unknown_error() :: {:error, any()}

  @max_annotations 500

  @spec get_all_for_site(Plausible.Site.t(), atom(), User.t() | nil, DateTimeRange.t()) ::
          {:error, :not_enough_permissions} | {:ok, list(Annotation.t())}
  def get_all_for_site(site, site_role, user, range_in_site_tz) do
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

    fields = [:id, :note, :type, :datetime, :granularity, :site_id, :inserted_at, :updated_at]

    in_range_clause =
      dynamic(
        [annotation],
        (annotation.granularity == :minute and
           annotation.datetime >= ^minute_granularity_range.first and
           annotation.datetime <= ^minute_granularity_range.last) or
          (annotation.granularity == :date and
             annotation.datetime >=
               ^date_granularity_range_first and
             annotation.datetime <=
               ^date_granularity_range_last)
      )

    cond do
      site_role in [:public] ->
        annotations =
          Repo.all(
            from(annotation in Annotation,
              inner_join: site in assoc(annotation, :site),
              select: ^fields,
              where: annotation.site_id == ^site.id,
              where: annotation.type == :site,
              where: ^in_range_clause,
              order_by: [desc: annotation.updated_at, desc: annotation.id],
              preload: [site: site]
            )
          )

        {:ok, annotations}

      site_role in roles_with_personal_annotations() or
          site_role in roles_with_maybe_site_annotations() ->
        fields = fields ++ [:owner_id]

        annotations =
          Repo.all(
            from(annotation in Annotation,
              inner_join: site in assoc(annotation, :site),
              inner_join: owner in assoc(annotation, :owner),
              select: ^fields,
              where: annotation.site_id == ^site.id,
              where:
                annotation.type == :site or
                  (annotation.type == :personal and annotation.owner_id == ^user.id),
              where: ^in_range_clause,
              order_by: [desc: annotation.updated_at, desc: annotation.id],
              preload: [site: site, owner: owner]
            )
          )

        {:ok, annotations}

      true ->
        {:error, :not_enough_permissions}
    end
  end

  @spec get_one(User.t(), Plausible.Site.t(), atom(), pos_integer() | nil) ::
          {:ok, Annotation.t()}
          | error_not_enough_permissions()
          | error_annotation_not_found()
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

  @spec insert_one(User.t(), Plausible.Site.t(), atom(), map()) ::
          {:ok, Annotation.t()}
          | error_not_enough_permissions()
          | error_invalid_annotation()
          | error_annotation_limit_reached()
          | unknown_error()
  def insert_one(user, site, site_role, params) do
    params = maybe_coerce_naive_datetime(params, site.timezone)

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

  @spec update_one(User.t(), Plausible.Site.t(), atom(), pos_integer(), map()) ::
          {:ok, Annotation.t()}
          | error_not_enough_permissions()
          | error_invalid_annotation()
          | unknown_error()
  def update_one(user, site, site_role, annotation_id, params) do
    params = maybe_coerce_naive_datetime(params, site.timezone)

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
  end

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
  end

  def user_removed(user) do
    Repo.delete_all(
      from(annotation in Annotation,
        as: :annotation,
        where: annotation.owner_id == ^user.id,
        where: annotation.type == :personal
      )
    )

    #  Site annotations are set to owner=null via ON DELETE SET NULL
  end

  def delete_one(user, %Plausible.Site{} = site, site_role, annotation_id) do
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

  @spec do_get_one(User.t(), Plausible.Site.t(), pos_integer() | nil) :: Annotation.t() | nil
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

    cond do
      (existing_annotation_type == :site or
         updating_to_site_annotation?) and site_role in roles_with_maybe_site_annotations() and
          site_annotations_available?(site) ->
        :ok

      existing_annotation_type == :personal and not updating_to_site_annotation? and
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

  def roles_with_personal_annotations(), do: @roles_with_personal_annotations
  def roles_with_maybe_site_annotations(), do: @roles_with_maybe_site_annotations

  def site_annotations_available?(%Plausible.Site{} = site),
    # this feature is bundled with SiteSegments
    do: Plausible.Billing.Feature.SiteSegments.check_availability(site.team) == :ok

  # If `datetime` is a naive ISO 8601 string (no UTC offset or Z suffix), interpret
  # it as a local time in the site's timezone and convert to UTC before the changeset
  # runs. This lets callers supply times in their local context without manually
  # computing offsets.
  #
  # DST edge cases:
  #   - gap (spring-forward): the missing hour is resolved to just-after the gap
  #   - ambiguous (fall-back): the earlier of the two possibilities is used
  #
  # All other `datetime` values (bare dates, full UTC strings, invalid strings) pass
  # through unchanged and are handled downstream by the changeset.
  defp maybe_coerce_naive_datetime(%{"datetime" => dt} = params, timezone)
       when is_binary(dt) do
    with {:error, _} <- DateTime.from_iso8601(dt),
         {:ok, naive_dt} <- NaiveDateTime.from_iso8601(dt) do
      utc_dt =
        case DateTime.from_naive(naive_dt, timezone) do
          {:ok, local_dt} -> DateTime.shift_zone!(local_dt, "Etc/UTC")
          {:ambiguous, first, _second} -> DateTime.shift_zone!(first, "Etc/UTC")
          {:gap, _just_before, just_after} -> DateTime.shift_zone!(just_after, "Etc/UTC")
        end

      Map.put(params, "datetime", utc_dt)
    else
      _ -> params
    end
  end

  defp maybe_coerce_naive_datetime(params, _timezone), do: params
end
