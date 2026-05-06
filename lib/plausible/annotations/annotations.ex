defmodule Plausible.Annotations do
  @moduledoc """
  Module for accessing Annotations.
  """
  alias Plausible.Annotations.Annotation
  alias Plausible.Repo
  import Ecto.Query

  @roles_with_personal_annotations [:billing, :viewer, :editor, :admin, :owner, :super_admin]
  @roles_with_maybe_site_annotations [:editor, :admin, :owner, :super_admin]

  @type error_not_enough_permissions() :: {:error, :not_enough_permissions}
  @type error_annotation_not_found() :: {:error, :annotation_not_found}
  @type error_annotation_limit_reached() :: {:error, :annotations_limit_reached}
  @type error_invalid_annotation() :: {:error, {:invalid_annotation, Keyword.t()}}
  @type unknown_error() :: {:error, any()}

  @max_annotations 500

  def get_all_for_site(%Plausible.Site{} = site, site_role) do
    fields = [:id, :note, :type, :datetime, :granularity, :inserted_at, :updated_at]

    cond do
      site_role in [:public] ->
        annotations =
          Repo.all(
            from(annotation in Annotation,
              select: ^fields,
              where: annotation.site_id == ^site.id,
              order_by: [desc: annotation.updated_at, desc: annotation.id]
            )
          )

        {:ok, Enum.map(annotations, &localize_annotation(&1, site.timezone))}

      site_role in @roles_with_personal_annotations or
          site_role in @roles_with_maybe_site_annotations ->
        fields = fields ++ [:owner_id]

        annotations =
          Repo.all(
            from(annotation in Annotation,
              select: ^fields,
              where: annotation.site_id == ^site.id,
              order_by: [desc: annotation.updated_at, desc: annotation.id],
              preload: [:owner]
            )
          )

        {:ok, Enum.map(annotations, &localize_annotation(&1, site.timezone))}

      true ->
        {:error, :not_enough_permissions}
    end
  end

  @spec get_one(pos_integer(), Plausible.Site.t(), atom(), pos_integer() | nil) ::
          {:ok, Annotation.t()}
          | error_not_enough_permissions()
          | error_annotation_not_found()
  def get_one(user_id, site, site_role, annotation_id) do
    if site_role in roles_with_personal_annotations() do
      case do_get_one(user_id, site.id, annotation_id) do
        %Annotation{} = annotation -> {:ok, annotation}
        nil -> {:error, :annotation_not_found}
      end
    else
      {:error, :not_enough_permissions}
    end
  end

  @spec insert_one(pos_integer(), Plausible.Site.t(), atom(), map()) ::
          {:ok, Annotation.t()}
          | error_not_enough_permissions()
          | error_invalid_annotation()
          | error_annotation_limit_reached()
          | unknown_error()

  def insert_one(
        user_id,
        %Plausible.Site{} = site,
        site_role,
        %{} = params
      ) do
    params = maybe_coerce_naive_datetime(params, site.timezone)

    with :ok <- can_insert_one?(site, site_role, params),
         %{valid?: true} = changeset <-
           Annotation.changeset(
             %Annotation{},
             Map.merge(params, %{"site_id" => site.id, "owner_id" => user_id})
           ) do
      {:ok, changeset |> Repo.insert!() |> Repo.preload(:owner) |> localize_annotation(site.timezone)}
    else
      %{valid?: false, errors: errors} ->
        {:error, {:invalid_annotation, errors}}

      {:error, _type} = error ->
        error
    end
  end

  @spec update_one(pos_integer(), Plausible.Site.t(), atom(), pos_integer(), map()) ::
          {:ok, Annotation.t()}
          | error_not_enough_permissions()
          | error_invalid_annotation()
          | unknown_error()

  def update_one(
        user_id,
        %Plausible.Site{} = site,
        site_role,
        annotation_id,
        %{} = params
      ) do
    params = maybe_coerce_naive_datetime(params, site.timezone)

    with {:ok, annotation} <- get_one(user_id, site, site_role, annotation_id),
         :ok <- can_update_one?(site, site_role, params, annotation.type),
         %{valid?: true} = changeset <-
           Annotation.changeset(
             annotation,
             Map.merge(params, %{"owner_id" => user_id})
           ) do
      Repo.update!(changeset)

      {:ok, Repo.reload!(annotation) |> Repo.preload(:owner) |> localize_annotation(site.timezone)}
    else
      %{valid?: false, errors: errors} ->
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

  def delete_one(user_id, %Plausible.Site{} = site, site_role, annotation_id) do
    with {:ok, annotation} <- get_one(user_id, site, site_role, annotation_id) do
      cond do
        annotation.type == :site and site_role in roles_with_maybe_site_annotations() ->
          {:ok, do_delete_one(annotation) |> localize_annotation(site.timezone)}

        annotation.type == :personal and site_role in roles_with_personal_annotations() ->
          {:ok, do_delete_one(annotation) |> localize_annotation(site.timezone)}

        true ->
          {:error, :not_enough_permissions}
      end
    end
  end

  @spec do_get_one(pos_integer(), pos_integer(), pos_integer() | nil) ::
          Annotation.t() | nil
  defp do_get_one(user_id, site_id, annotation_id)

  defp do_get_one(_user_id, _site_id, nil) do
    nil
  end

  defp do_get_one(user_id, site_id, annotation_id) do
    query =
      from(annotation in Annotation,
        where: annotation.site_id == ^site_id,
        where: annotation.id == ^annotation_id,
        where: annotation.type == :site or annotation.owner_id == ^user_id,
        preload: [:owner]
      )

    Repo.one(query)
  end

  defp do_delete_one(annotation) do
    Repo.delete!(annotation)
    annotation
  end

  defp can_update_one?(%Plausible.Site{} = site, site_role, params, existing_annotation_type) do
    updating_to_site_annotation? = params["type"] == "site"

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

  defp can_insert_one?(%Plausible.Site{} = site, site_role, params) do
    cond do
      count_annotations(site.id) >= @max_annotations ->
        {:error, :annotations_limit_reached}

      params["type"] == "site" and site_role in roles_with_maybe_site_annotations() and
          site_annotations_available?(site) ->
        :ok

      params["type"] == "personal" and
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
    do: Plausible.Billing.Feature.SiteAnnotations.check_availability(site.team) == :ok

  @doc """
  iex> serialize_first_error([{"name", {"should be at most %{count} byte(s)", [count: 255]}}])
  "name should be at most 255 byte(s)"
  """
  def serialize_first_error(errors) do
    {field, {message, opts}} = List.first(errors)

    formatted_message =
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)

    "#{field} #{formatted_message}"
  end

  # For date granularity, the UTC date component IS the annotation date — callers
  # store UTC midnight of their intended local date, so no timezone shift is needed.
  # Return just the Date so the JSON response matches the bare-date input format.
  defp localize_annotation(%Annotation{granularity: :date} = annotation, _timezone) do
    %{annotation | datetime: DateTime.to_date(annotation.datetime)}
  end

  # For minute granularity, shift the stored UTC moment to the site's local timezone
  # and strip the offset so the response is a naive local time string.
  defp localize_annotation(%Annotation{granularity: :minute} = annotation, timezone) do
    naive_local =
      annotation.datetime
      |> DateTime.shift_zone!(timezone)
      |> DateTime.to_naive()

    %{annotation | datetime: naive_local}
  end

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
    case DateTime.from_iso8601(dt) do
      {:ok, _, _} ->
        params

      {:error, _} ->
        case NaiveDateTime.from_iso8601(dt) do
          {:ok, naive_dt} ->
            utc_dt =
              case DateTime.from_naive(naive_dt, timezone) do
                {:ok, local_dt} -> DateTime.shift_zone!(local_dt, "Etc/UTC")
                {:ambiguous, first, _second} -> DateTime.shift_zone!(first, "Etc/UTC")
                {:gap, _just_before, just_after} -> DateTime.shift_zone!(just_after, "Etc/UTC")
              end

            Map.put(params, "datetime", DateTime.to_iso8601(utc_dt))

          _ ->
            params
        end
    end
  end

  defp maybe_coerce_naive_datetime(params, _timezone), do: params
end
