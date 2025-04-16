defmodule PlausibleWeb.Live.CSVImport do
  @moduledoc """
  LiveView allowing uploading CSVs for imported tables to S3 or local storage
  """

  use PlausibleWeb, :live_view

  require Plausible.Imported.SiteImport
  alias Plausible.Imported.CSVImporter
  alias Plausible.Imported

  # :not_mounted_at_router ensures we have already done auth checks in the controller
  # if this liveview becomes available from the router, please make sure
  # to check that site_role is allowed to make site imports
  @impl true
  def mount(:not_mounted_at_router, session, socket) do
    %{"site_id" => site_id, "storage" => storage} = session

    upload_opts = [
      accept: [".csv", "text/csv"],
      auto_upload: true,
      max_entries: length(Imported.tables()),
      # 1GB
      max_file_size: 1_000_000_000,
      progress: &handle_progress/3
    ]

    upload_opts =
      case storage do
        "s3" -> [{:external, &presign_upload/2} | upload_opts]
        "local" -> upload_opts
      end

    upload_consumer =
      case storage do
        "s3" ->
          fn meta, entry ->
            {:ok, %{"s3_url" => meta.s3_url, "filename" => entry.client_name}}
          end

        "local" ->
          local_dir = CSVImporter.local_dir(site_id)
          File.mkdir_p!(local_dir)

          fn meta, entry ->
            local_path = Path.join(local_dir, Path.basename(meta.path))
            Plausible.File.mv!(meta.path, local_path)
            {:ok, %{"local_path" => local_path, "filename" => entry.client_name}}
          end
      end

    %{assigns: %{site: site}} =
      socket = assign_new(socket, :site, fn -> Plausible.Repo.get!(Plausible.Site, site_id) end)

    # we'll listen for new completed imports to know
    # when to reload the occupied ranges
    if connected?(socket), do: Imported.listen()

    occupied_ranges = Imported.get_occupied_date_ranges(site)
    native_stats_start_date = Plausible.Sites.native_stats_start_date(site)

    socket =
      socket
      |> assign(
        site_id: site_id,
        storage: storage,
        upload_consumer: upload_consumer,
        occupied_ranges: occupied_ranges,
        native_stats_start_date: native_stats_start_date
      )
      |> allow_upload(:import, upload_opts)
      |> process_imported_tables()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <form action="#" method="post" phx-change="validate-upload-form" phx-submit="submit-upload-form">
        <.csv_picker upload={@uploads.import} imported_tables={@imported_tables} />
        <.confirm_button date_range={@clamped_date_range} can_confirm?={@can_confirm?} />
        <.maybe_date_range_warning
          :if={@original_date_range}
          clamped={@clamped_date_range}
          original={@original_date_range}
        />
        <p :for={error <- upload_errors(@uploads.import)} class="text-red-400">
          {error_to_string(error)}
        </p>
      </form>
    </div>
    """
  end

  defp csv_picker(assigns) do
    ~H"""
    <label
      phx-drop-target={@upload.ref}
      class="block border-2 dark:border-gray-600 rounded-md p-4 hover:bg-gray-50 dark:hover:bg-gray-900 hover:border-indigo-500 dark:hover:border-indigo-600 transition cursor-pointer"
    >
      <div class="hidden md:flex items-center text-gray-500 dark:text-gray-500">
        <Heroicons.document_plus class="w-5 h-5 transition" />
        <span class="ml-1.5 text-sm">
          (or drag-and-drop your unzipped CSVs here)
        </span>
        <.live_file_input upload={@upload} class="hidden" />
      </div>

      <ul id="imported-tables" class="truncate mt-3.5 mb-0.5 space-y-1.5">
        <.imported_table
          :for={{table, upload} <- @imported_tables}
          table={table}
          upload={upload}
          errors={if(upload, do: upload_errors(@upload, upload), else: [])}
        />
      </ul>
    </label>
    """
  end

  defp confirm_button(assigns) do
    ~H"""
    <.button type="submit" disabled={not @can_confirm?} class="w-full">
      <%= if @date_range do %>
        Confirm import <.dates range={@date_range} />
      <% else %>
        Confirm import
      <% end %>
    </.button>
    """
  end

  defp maybe_date_range_warning(assigns) do
    ~H"""
    <%= if @clamped do %>
      <.notice :if={@clamped != @original} title="Dates Adjusted" theme={:yellow} class="mt-4">
        The dates <.dates range={@original} />
        overlap with previous imports, so we'll use the next best period, <.dates range={@clamped} />
      </.notice>
    <% else %>
      <.notice title="Dates Conflict" theme={:red} class="mt-4">
        The dates <.dates range={@original} />
        overlap with dates we've already imported and cannot be used for new imports.
      </.notice>
    <% end %>
    """
  end

  defp dates(assigns) do
    ~H"""
    <span class="whitespace-nowrap">
      <span class="font-medium">{@range.first}</span>
      to <span class="font-medium">{@range.last}</span>
    </span>
    """
  end

  defp imported_table(assigns) do
    status =
      cond do
        assigns.upload && assigns.upload.progress == 100 -> :success
        assigns.upload && assigns.upload.progress > 0 -> :in_progress
        not Enum.empty?(assigns.errors) -> :error
        true -> :empty
      end

    assigns = assign(assigns, status: status)

    ~H"""
    <li id={@table} class="ml-0.5">
      <div class="flex items-center space-x-2 text-gray-600 dark:text-gray-500">
        <Heroicons.document_check :if={@status == :success} class="w-4 h-4" />
        <.spinner :if={@status == :in_progress} class="w-4 h-4" />
        <Heroicons.document :if={@status == :empty} class="w-4 h-4 opacity-80" />
        <Heroicons.document :if={@status == :error} class="w-4 h-4 text-red-600 dark:text-red-700" />

        <span class={[
          "text-sm",
          if(@status == :empty, do: "opacity-80"),
          if(@status == :error, do: "text-red-600 dark:text-red-700")
        ]}>
          <%= if @upload do %>
            {@upload.client_name}
          <% else %>
            {@table}_YYYYMMDD_YYYYMMDD.csv
          <% end %>
        </span>
      </div>

      <p :for={error <- @errors} class="ml-6 text-sm text-red-600 dark:text-red-700">
        {error_to_string(error)}
      </p>
    </li>
    """
  end

  @impl true
  def handle_event("validate-upload-form", _params, socket) do
    {:noreply, process_imported_tables(socket)}
  end

  def handle_event("submit-upload-form", _params, socket) do
    %{
      storage: storage,
      site: site,
      current_user: current_user,
      clamped_date_range: clamped_date_range,
      upload_consumer: upload_consumer
    } =
      socket.assigns

    uploads = consume_uploaded_entries(socket, :import, upload_consumer)

    {:ok, _job} =
      CSVImporter.new_import(site, current_user,
        start_date: clamped_date_range.first,
        end_date: clamped_date_range.last,
        uploads: uploads,
        storage: storage
      )

    redirect_to =
      Routes.site_path(socket, :settings_imports_exports, site.domain)

    {:noreply, redirect(socket, to: redirect_to)}
  end

  @impl true
  def handle_info({:notification, :analytics_imports_jobs, details}, socket) do
    site = socket.assigns.site

    socket =
      if details["site_id"] == site.id and details["event"] == "complete" do
        occupied_ranges = Imported.get_occupied_date_ranges(site)
        socket |> assign(occupied_ranges: occupied_ranges) |> process_imported_tables()
      else
        socket
      end

    {:noreply, socket}
  end

  defp error_to_string(:too_large), do: "is too large (max size is 1 gigabyte)"
  defp error_to_string(:too_many_files), do: "too many files"
  defp error_to_string(:not_accepted), do: "unacceptable file types"
  defp error_to_string(:external_client_failure), do: "browser upload failed"

  defp presign_upload(entry, socket) do
    %{s3_url: s3_url, presigned_url: upload_url} =
      Plausible.S3.import_presign_upload(socket.assigns.site_id, random_suffix(entry.client_name))

    {:ok, %{uploader: "S3", s3_url: s3_url, url: upload_url}, socket}
  end

  defp random_suffix(filename) do
    # based on Plug.Upload.path/2
    # https://github.com/elixir-plug/plug/blob/eabf0b9d43060c10663a9105cb1baf984d272a6c/lib/plug/upload.ex#L154-L159
    sec = Integer.to_string(:os.system_time(:second))
    rand = Integer.to_string(:rand.uniform(999_999_999_999))
    scheduler_id = Integer.to_string(:erlang.system_info(:scheduler_id))
    filename <> "-" <> sec <> "-" <> rand <> "-" <> scheduler_id
  end

  defp handle_progress(:import, entry, socket) do
    if entry.done? do
      {:noreply, process_imported_tables(socket)}
    else
      {:noreply, socket}
    end
  end

  defp process_imported_tables(socket) do
    tables = Imported.tables()
    {completed, in_progress} = uploaded_entries(socket, :import)

    {valid_uploads, invalid_uploads} =
      Enum.split_with(completed ++ in_progress, &CSVImporter.valid_filename?(&1.client_name))

    imported_tables_all_uploads =
      Enum.map(tables, fn table ->
        uploads =
          Enum.filter(valid_uploads, fn upload ->
            CSVImporter.extract_table(upload.client_name) == table
          end)

        {upload, replaced_uploads} = List.pop_at(uploads, -1)
        {table, upload, replaced_uploads}
      end)

    imported_tables =
      Enum.map(imported_tables_all_uploads, fn {table, upload, _replaced_uploads} ->
        {table, upload}
      end)

    replaced_uploads =
      Enum.flat_map(imported_tables_all_uploads, fn {_table, _upload, replaced_uploads} ->
        replaced_uploads
      end)

    original_date_range = CSVImporter.date_range(Enum.map(valid_uploads, & &1.client_name))

    clamped_date_range =
      if original_date_range do
        %Date.Range{first: start_date, last: end_date} = original_date_range

        %{
          site: site,
          occupied_ranges: occupied_ranges,
          native_stats_start_date: native_stats_start_date
        } = socket.assigns

        cutoff_date = native_stats_start_date || Timex.today(site.timezone)

        case Imported.clamp_dates(occupied_ranges, cutoff_date, start_date, end_date) do
          {:ok, start_date, end_date} -> Date.range(start_date, end_date)
          {:error, :no_time_window} -> nil
        end
      end

    all_uploaded? = completed != [] and in_progress == []
    can_confirm? = all_uploaded? and not is_nil(clamped_date_range)

    socket
    |> cancel_uploads(invalid_uploads)
    |> cancel_uploads(replaced_uploads)
    |> assign(
      imported_tables: imported_tables,
      can_confirm?: can_confirm?,
      original_date_range: original_date_range,
      clamped_date_range: clamped_date_range
    )
  end

  defp cancel_uploads(socket, uploads) do
    Enum.reduce(uploads, socket, fn upload, socket ->
      cancel_upload(socket, :import, upload.ref)
    end)
  end
end
