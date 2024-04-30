defmodule Plausible.Imported.Importer do
  @moduledoc """
  Behaviour that should be implemented for each import source.

  All imports are executed as background jobs run via `Plausible.Workers.ImportAnalytics`
  Oban worker. Each import source must define a module conforming `Importer` behaviour.

  The callbacks that need to be implemented:

  * `name/0` - Returns import source name as an atom. Example: `:universal_analytics`.
  * `label/0` - Descriptive, display friendly name of the source.
    Example: "Google Analytics".
  * `email_template/0` - Name of the email template to use for notifications in
    `PlausibleWeb.Email` (`import_success` and `import_failure`). The template
    should have content customized for a particular source.
  * `parse_args/1` - Receives Oban job arguments coming from `new_import/3`. Whatever
    options were passed to `new_import/3` will be present in the input map with string
    keys and values serialized to primitives. If, for instance `start_date: ~D[2024-01-03]`
    is passed as an option, `parse_args/1` receives `%{..., "start_date" => "2024-01-03"}`.
    The expectation is parsing the map values producing a keyword list of options to
    pass to `import_data/2`.
  * `import_data/2` - Receives site import struct and options produced by `parse_args/1`.
    This is where all the import processing is done. The way the import is implemented
    is entirely arbitrary except the requirement that the process as a whole must
    by synchronous. The callback is expected to return either `:ok` or `{:ok, %{...}}`
    on successful import or `{:error, ...}` on failure. The map in success tuple is
    used for updating site import struct and is passed to `on_success/2` callback.
    Please note that error tuple should be only returned on errors that can't be
    recovered from. For transient errors, the import should throw an exception or
    simply crash. The error tuple has an alternative `{error, reason, opts}` form,
    where `opts` allow to skip purging imported data so far via `skip_purge?` flag
    and skip marking the import as failed and notifying the user via `skip_mark_failed?`
    flag. Both flags are booleans.
  * `before_start/2` - Optional callback run right before scheduling import job. It's
    expected to either return `{:ok, site_import}` for the import to proceed
    or `{:error, ...}` tuple, which will be returned from `new_import/3` call.
    The `site_import` can be altered or replaced at this stage. The second argument
    are opts passed to `new_import/3`.
  * `on_success/2` - Optional callback run once site import is completed. Receives map
    returned from `import_data/2`. Expected to always return `:ok`.
  * `on_failure/1` - Optional callback run when import job fails permanently.

  All sources must be added to the list in `Plausible.Imported.ImportSources`.

  In order to schedule a new import job using a given source, respective importer's
  `new_import/3` function must be called. It accepts site, user who is doing the import
  and any options necessary to carry out the import.

  There's an expectation that `start_date` and `end_date` are provided either as options
  passed to `new_import/3` or data in map returned from `import_data/2`. If these parameters
  are not provided, the import will eventually crash. These parameters define time range
  of imported data which is in turn used for efficient querying.

  Logic running inside `import_data/2` is expected to populated all `imported_*` tables
  in ClickHouse with `import_id` column set to site import's ID.

  Managing any configuration or authentication prior to running import is outside of
  scope of importer logic and is expected to be implemented separately.

  ## Running import fully synchronously

  In case it's necessary to run the whole import job fully synchronously, the
  `Plausible.Workers.ImportAnalytics` worker sends an `Oban.Notifier` message
  on completion, failure or transient failure of the import.

  A basic usage scenario looks like this:

  ```elixir
  {:ok, job} = Plausible.Imported.NoopImporter.new_import(
    site,
    user,
    start_date: ~D[2005-01-01],
    end_date: Date.utc_today(),
    # this option is necessary to setup the calling process as listener
    listen?: true
  )

  import_id = job.args[:import_id]

  receive do
    {:notification, :analytics_imports_jobs, %{"event" => "complete", "import_id" => ^import_id}} ->
      IO.puts("Job completed")

    {:notification, :analytics_imports_jobs, %{"event" => "transient_fail", "import_id" => ^import_id}} ->
      IO.puts("Job failed transiently")

    {:notification, :analytics_imports_jobs, %{"event" => "fail", "import_id" => ^import_id}} ->
      IO.puts("Job failed permanently")
  after
    15_000 ->
      IO.puts("Job didn't finish in 15 seconds")
  end
  ```

  In a more realistic scenario, job scheduling will be done inside a GenServer process
  like LiveView, where notifications can be listened for via `handle_info/2`.
  """

  alias Plausible.Imported
  alias Plausible.Imported.SiteImport
  alias Plausible.Repo

  @callback name() :: atom()
  @callback label() :: String.t()
  @callback email_template() :: String.t()
  @callback parse_args(map()) :: Keyword.t()
  @callback import_data(SiteImport.t(), Keyword.t()) ::
              :ok | {:error, any()} | {:error, any(), Keyword.t()}
  @callback before_start(SiteImport.t(), Keyword.t()) :: {:ok, SiteImport.t()} | {:error, any()}
  @callback on_success(SiteImport.t(), map()) :: :ok
  @callback on_failure(SiteImport.t()) :: :ok

  defmacro __using__(_opts) do
    quote do
      @behaviour Plausible.Imported.Importer

      @spec new_import(Plausible.Site.t(), Plausible.Auth.User.t(), Keyword.t()) ::
              {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t() | :import_in_progress | any()}
      def new_import(site, user, opts) do
        Plausible.Imported.Importer.new_import(name(), site, user, opts, &before_start/2)
      end

      @doc false
      @spec run_import(SiteImport.t(), map()) :: {:ok, SiteImport.t()} | {:error, :any}
      def run_import(site_import, args) do
        Plausible.Imported.Importer.run_import(
          site_import,
          args,
          &parse_args/1,
          &import_data/2,
          &on_success/2
        )
      end

      @doc false
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
      def before_start(site_import, _opts), do: {:ok, site_import}

      @impl true
      def on_success(_site_import, _extra_data), do: :ok

      @impl true
      def on_failure(_site_import), do: :ok

      defoverridable before_start: 2, on_success: 2, on_failure: 1
    end
  end

  @doc false
  def new_import(source, site, user, opts, before_start_fun) do
    import_params =
      opts
      |> Keyword.take([:label, :start_date, :end_date, :legacy])
      |> Keyword.put(:source, source)
      |> Map.new()

    Repo.transaction(fn ->
      result =
        site
        |> SiteImport.create_changeset(user, import_params)
        |> Repo.insert()

      with {:ok, site_import} <- result,
           {:ok, site_import} <- before_start_fun.(site_import, opts),
           {:ok, job} <- schedule_job(site_import, opts) do
        job
      else
        {:error, error} ->
          Repo.rollback(error)
      end
    end)
  end

  @doc false
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
        {:error, error, []}

      {:error, error, opts} ->
        {:error, error, opts}
    end
  end

  @oban_channel :analytics_imports_jobs

  @doc false
  def notify(site_import, event) do
    Oban.Notifier.notify(Oban, @oban_channel, %{
      "event" => event,
      "import_id" => site_import.id,
      "site_id" => site_import.site_id
    })
  end

  @doc """
  Allows to explicitly start listening for importer job notifications.

  Listener must explicitly filter out a subset of imports that apply to the given context.
  """
  @spec listen() :: :ok
  def listen() do
    :ok = Oban.Notifier.listen([@oban_channel])
  end

  defp schedule_job(site_import, opts) do
    {listen?, opts} = Keyword.pop(opts, :listen?, false)
    {job_opts, opts} = Keyword.pop(opts, :job_opts, [])

    if listen? do
      :ok = listen()
    end

    if not Imported.other_imports_in_progress?(site_import) do
      opts
      |> Keyword.put(:import_id, site_import.id)
      |> Map.new()
      |> Plausible.Workers.ImportAnalytics.new(job_opts)
      |> Oban.insert()
    else
      {:error, :import_in_progress}
    end
  end

  defp mark_complete(site_import, extra_data, on_success_fun) do
    site_import =
      site_import
      |> SiteImport.complete_changeset(extra_data)
      |> Repo.update!()

    :ok = on_success_fun.(site_import, extra_data)

    site_import
  end
end
