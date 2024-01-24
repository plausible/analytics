defmodule Plausible.Imported.Importer do
  @moduledoc """
  Behaviour that should be implemented for each new import source.

  The new source should also be added to the list in `Plausible.Imported.ImportSources`.
  """

  alias Plausible.Imported.SiteImport
  alias Plausible.Repo

  @callback name() :: String.t()
  @callback parse_args(map()) :: Keyword.t()
  @callback import_data(Plausible.Site.t(), Keyword.t()) :: :ok | {:error, any()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Plausible.Imported.Importer

      @spec new_import(Plausible.Site.t(), Plausible.Auth.User.t(), Keyword.t()) ::
              {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
      def new_import(site, user, opts) do
        Plausible.Imported.Importer.new_import(name(), site, user, opts)
      end

      def run_import(import_id, args) do
        Plausible.Imported.Importer.run_import(import_id, args, &parse_args/1, &import_data/2)
      end
    end
  end

  def new_import(source, site, user, opts) do
    import_params =
      opts
      |> Keyword.take([:start_date, :end_date])
      |> Keyword.put(:source, source)
      |> Map.new()

    Repo.transaction(fn ->
      result =
        site
        |> SiteImport.create_changeset(user, import_params)
        |> Repo.insert()

      case result do
        {:ok, site_import} ->
          job_params =
            opts
            |> Keyword.put(:import_id, site_import.id)
            |> Map.new()

          job_changeset = Plausible.Workers.ImportAnalytics.new(job_params)

          case Oban.insert(job_changeset) do
            {:ok, job} ->
              job

            {:error, changeset} ->
              Repo.rollback(changeset)
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def run_import(site_import, args, parse_args_fun, import_fun) do
    site_import =
      site_import
      |> SiteImport.start_changeset()
      |> Repo.update!()
      |> Repo.preload(:site)

    import_opts = parse_args_fun.(args)

    case import_fun.(site_import.site, import_opts) do
      :ok ->
        site_import =
          site_import
          |> SiteImport.complete_changeset()
          |> Repo.update!()

        {:ok, site_import}

      {:ok, extra_data} ->
        site_import =
          site_import
          |> SiteImport.complete_changeset(extra_data)
          |> Repo.update!()

        {:ok, site_import}

      {:error, error} ->
        {:error, error}
    end
  end
end
