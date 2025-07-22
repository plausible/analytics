defmodule Plausible.Audit.Repo do
  @moduledoc """
  Equips Ecto.Repo with audited insert/update/delete variants.
  This module will potentially augment db operations with transaction wrappers.

  Audit is EE-specific, so CE gets only no-op adapter functions.
  """
  use Plausible

  @callback update_with_audit(
              changeset :: Ecto.Changeset.t(),
              entry_name :: any(),
              params :: map()
            ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}

  @callback update_with_audit!(
              changeset :: Ecto.Changeset.t(),
              entry_name :: any(),
              params :: map()
            ) :: Ecto.Schema.t()

  @callback insert_with_audit(
              changeset :: Ecto.Changeset.t(),
              entry_name :: any(),
              params :: map()
            ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}

  @callback insert_with_audit!(
              changeset :: Ecto.Changeset.t(),
              entry_name :: any(),
              params :: map(),
              insert_opts :: keyword()
            ) :: Ecto.Schema.t()

  @callback delete_with_audit!(
              resource :: Ecto.Schema.t() | Ecto.Changeset.t(),
              entry_name :: any(),
              params :: map()
            ) :: Ecto.Schema.t()

  defmacro __using__(_opts) do
    on_ee do
      quote do
        @behaviour Plausible.Audit.Repo

        def update_with_audit(%Ecto.Changeset{} = changeset, entry_name, params \\ %{}) do
          case update(changeset) do
            {:ok, result} ->
              store_audit(entry_name, result, changeset, params)

              {:ok, result}

            other ->
              other
          end
        end

        def update_with_audit!(%Ecto.Changeset{} = changeset, entry_name, params \\ %{}) do
          result = update!(changeset)
          store_audit(entry_name, result, changeset, params)
          result
        end

        def insert_with_audit(%Ecto.Changeset{} = changeset, entry_name, params \\ %{}) do
          case insert(changeset) do
            {:ok, result} ->
              store_audit(entry_name, result, params)

              {:ok, result}

            other ->
              other
          end
        end

        def insert_with_audit!(
              %Ecto.Changeset{} = changeset,
              entry_name,
              params \\ %{},
              insert_opts \\ []
            ) do
          result = insert!(changeset, insert_opts)
          store_audit(entry_name, result, params)
          result
        end

        def delete_with_audit!(resource, entry_name, params \\ %{}) do
          result = delete!(resource)
          store_audit(entry_name, resource, params)
          result
        end

        defp store_audit(entry_name, result, changeset, params) do
          entry_name
          |> Plausible.Audit.Entry.new(result, params)
          |> Plausible.Audit.Entry.include_change(changeset)
          |> Plausible.Audit.Entry.persist!()
        end

        defp store_audit(entry_name, result, params) do
          entry_name
          |> Plausible.Audit.Entry.new(result, params)
          |> Plausible.Audit.Entry.include_change(result)
          |> Plausible.Audit.Entry.persist!()
        end
      end
    else
      quote do
        @behaviour Plausible.Audit.Repo

        def update_with_audit(changeset, _, _) do
          update(changeset)
        end

        def update_with_audit!(changeset, _, _) do
          update!(changeset)
        end

        def insert_with_audit(changeset, _, _) do
          insert(changeset)
        end

        def insert_with_audit!(changeset, _, _, _) do
          insert!(changeset)
        end

        def delete_with_audit!(resource, _, _) do
          delete!(resource)
        end
      end
    end
  end
end
