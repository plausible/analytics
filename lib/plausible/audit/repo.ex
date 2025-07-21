defmodule Plausible.Audit.Repo do
  @moduledoc """
  Equips Ecto.Repo with audited insert/update/delete variants.
  This module will potentially augment db operations with transaction wrappers.
  """

  defmacro __using__(_opts) do
    quote do
      def update_with_audit(%Ecto.Changeset{} = changeset, entry_name, params \\ %{}) do
        case update(changeset) do
          {:ok, result} ->
            audit_update(entry_name, result, changeset, params)

            {:ok, result}

          other ->
            other
        end
      end

      def update_with_audit!(%Ecto.Changeset{} = changeset, entry_name, params \\ %{}) do
        result = update!(changeset)
        audit_update(entry_name, result, changeset, params)
        result
      end

      def insert_with_audit(%Ecto.Changeset{} = changeset, entry_name, params \\ %{}) do
        case insert(changeset) do
          {:ok, result} ->
            audit_insert(entry_name, result, params)

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
        audit_insert(entry_name, result, params)
        result
      end

      def delete_with_audit!(resource, entry_name, params \\ %{}) do
        result = delete!(resource)
        audit_deletion(entry_name, resource, params)
        result
      end

      defp audit_deletion(entry_name, resource, params) do
        entry_name
        |> Plausible.Audit.Entry.new(resource, params)
        |> Plausible.Audit.Entry.persist!()
      end

      defp audit_update(entry_name, result, changeset, params) do
        entry_name
        |> Plausible.Audit.Entry.new(result, params)
        |> Plausible.Audit.Entry.include_change(changeset)
        |> Plausible.Audit.Entry.persist!()
      end

      defp audit_insert(entry_name, result, params) do
        entry_name
        |> Plausible.Audit.Entry.new(result, params)
        |> Plausible.Audit.Entry.include_change(result)
        |> Plausible.Audit.Entry.persist!()
      end
    end
  end
end
