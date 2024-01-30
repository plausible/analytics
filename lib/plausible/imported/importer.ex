defmodule Plausible.Imported.Importer do
  @moduledoc """
  Behaviour that should be implemented for each new import source.

  The new source should also be added to the list in `Plausible.Imported.ImportSources`.
  """

  alias Plausible.Imported.SiteImport
  alias Plausible.Repo

  @callback name() :: atom()
  @callback label() :: String.t()
  @callback parse_args(map()) :: Keyword.t()
  @callback import_data(Plausible.Site.t(), Keyword.t()) :: :ok | {:error, any()}
  @callback before_start(SiteImport.t()) :: :ok | {:error, any()}
  @callback on_success(SiteImport.t()) :: :ok
  @callback on_failure(SiteImport.t()) :: :ok

  defmacro __using__(_opts) do
    quote do
      @behaviour Plausible.Imported.Importer

      @spec new_import(Plausible.Site.t(), Plausible.Auth.User.t(), Keyword.t()) ::
              {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
      def new_import(site, user, opts) do
        Plausible.Imported.Importer.new_import(name(), site, user, opts, &before_start/1)
      end

      @spec run_import(SiteImport.t(), Keyword.t()) :: :ok | {:error, :any}
      def run_import(site_import, args) do
        Plausible.Imported.Importer.run_import(
          site_import,
          args,
          &parse_args/1,
          &import_data/2,
          &on_success/1
        )
      end

      @spec mark_failed(SiteImport.t()) :: SiteImport.t()
      def mark_failed(site_import) do
        site_import =
          site_import
          |> SiteImport.fail_changeset()
          |> Repo.update!()

        :ok = on_failure(site_import)

        site_import
      end

      @impl true
      def before_start(_site_import), do: :ok

      @impl true
      def on_success(_site_import), do: :ok

      @impl true
      def on_failure(_site_import), do: :ok

      defoverridable before_start: 1, on_success: 1, on_failure: 1
    end
  end

  def new_import(source, site, user, opts, before_start_fun) do
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

      with {:ok, site_import} <- result,
           :ok <- before_start_fun.(site_import),
           {:ok, job} <- schedule_job(site_import, opts) do
        job
      else
        {:error, error} ->
          Repo.rollback(error)
      end
    end)
  end

  def run_import(site_import, args, parse_args_fun, import_fun, on_success_fun) do
    site_import =
      site_import
      |> SiteImport.start_changeset()
      |> Repo.update!()
      |> Repo.preload(:site)

    import_opts = parse_args_fun.(args)

    case import_fun.(site_import, import_opts) do
      :ok ->
        {:ok, mark_complete(site_import, %{}, on_success_fun)}

      {:ok, extra_data} ->
        {:ok, mark_complete(site_import, extra_data, on_success_fun)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp schedule_job(site_import, opts) do
    opts
    |> Keyword.put(:import_id, site_import.id)
    |> Map.new()
    |> Plausible.Workers.ImportAnalytics.new()
    |> Oban.insert()
  end

  defp mark_complete(site_import, extra_data, on_success_fun) do
    site_import =
      site_import
      |> SiteImport.complete_changeset(extra_data)
      |> Repo.update!()

    :ok = on_success_fun.(site_import)

    site_import
  end
end
