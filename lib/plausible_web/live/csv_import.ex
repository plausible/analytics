defmodule PlausibleWeb.Live.CSVImport do
  @moduledoc """
  LiveView allowing uploading CSVs for imported tables to S3 or local storage
  """

  use PlausibleWeb, :live_view
  require Plausible.Imported.SiteImport
  alias Plausible.Imported.CSVImporter

  # :not_mounted_at_router ensures we have already done auth checks in the controller
  # if this liveview becomes available from the router, please make sure
  # to check that current_user_role is allowed to make site imports
  @impl true
  def mount(:not_mounted_at_router, session, socket) do
    %{"site_id" => site_id, "current_user_id" => user_id, "storage" => storage} = session

    upload_opts = [
      accept: [".csv", "text/csv"],
      auto_upload: true,
      max_entries: length(Plausible.Imported.tables()),
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
            File.rename!(meta.path, local_path)
            {:ok, %{"local_path" => local_path, "filename" => entry.client_name}}
          end
      end

    %{assigns: %{site: site}} =
      socket = assign_new(socket, :site, fn -> Plausible.Repo.get!(Plausible.Site, site_id) end)

    occupied_ranges =
      site
      |> Plausible.Imported.list_all_imports(Plausible.Imported.SiteImport.completed())
      |> Enum.reject(&(Date.diff(&1.end_date, &1.start_date) < 2))
      |> Enum.map(&Date.range(&1.start_date, &1.end_date))

    cutoff_date = Plausible.Sites.native_stats_start_date(site) || Timex.today(site.timezone)

    socket =
      socket
      |> assign(
        site_id: site_id,
        user_id: user_id,
        storage: storage,
        upload_consumer: upload_consumer,
        occupied_ranges: occupied_ranges,
        cutoff_date: cutoff_date
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
        <.date_range_warning
          :if={@clamped_date_range != @original_date_range}
          clamped_date_range={@clamped_date_range}
          original_date_range={@original_date_range}
        />
        <p :for={error <- upload_errors(@uploads.import)} class="text-red-400">
          <%= error_to_string(error) %>
        </p>
      </form>
    </div>
    """
  end

  defp csv_picker(assigns) do
    ~H"""
    <label
      phx-drop-target={@upload.ref}
      class="block border-2 dark:border-gray-600 rounded p-4 group hover:border-indigo-500 dark:hover:border-indigo-600 transition cursor-pointer"
    >
      <div class="flex items-center">
        <div class="bg-gray-200 dark:bg-gray-600 rounded p-1 group-hover:bg-indigo-500 dark:group-hover:bg-indigo-600 transition">
          <Heroicons.document_plus class="w-5 h-5 group-hover:text-white transition" />
        </div>
        <span class="ml-2 text-sm text-gray-600 dark:text-gray-500">
          (or drag-and-drop your unzipped CSVs here)
        </span>
        <.live_file_input upload={@upload} class="hidden" />
      </div>

      <ul id="imported-tables" class="mt-3.5 mb-0.5 space-y-1.5">
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
    <button
      type="submit"
      disabled={not @can_confirm?}
      class={[
        "rounded-md w-full bg-indigo-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 disabled:bg-gray-400 dark:disabled:text-gray-400 dark:disabled:bg-gray-700 mt-4",
        unless(@can_confirm?, do: "cursor-not-allowed")
      ]}
    >
      <%= if @date_range do %>
        Confirm import from <%= @date_range.first %> to <%= @date_range.last %>
      <% else %>
        Confirm import
      <% end %>
    </button>
    """
  end

  defp date_range_warning(assigns) do
    ~H"""
    TODO
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
    <li id={@table} class="ml-1.5">
      <div class="flex items-center space-x-2">
        <Heroicons.document_check :if={@status == :success} class="w-4 h-4 text-indigo-600" />
        <PlausibleWeb.Components.Generic.spinner
          :if={@status == :in_progress}
          class="w-4 h-4 text-indigo-600"
        />
        <Heroicons.document :if={@status == :empty} class="w-4 h-4 text-gray-400 dark:text-gray-500" />
        <Heroicons.document :if={@status == :error} class="w-4 h-4 text-red-600 dark:text-red-700" />

        <span class={[
          "text-sm",
          if(@upload, do: "dark:text-gray-400", else: "text-gray-400 dark:text-gray-500"),
          if(@status == :error, do: "text-red-600 dark:text-red-700")
        ]}>
          <%= if @upload do %>
            <%= @upload.client_name %>
          <% else %>
            <%= @table %>_YYYYMMDD_YYYYMMDD.csv
          <% end %>
        </span>
      </div>

      <p :for={error <- @errors} class="ml-6 text-sm text-red-600 dark:text-red-700">
        <%= error_to_string(error) %>
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
      user_id: user_id,
      date_range: date_range,
      upload_consumer: upload_consumer
    } =
      socket.assigns

    user = Plausible.Repo.get!(Plausible.Auth.User, user_id)
    uploads = consume_uploaded_entries(socket, :import, upload_consumer)

    {:ok, _job} =
      CSVImporter.new_import(site, user,
        start_date: date_range.first,
        end_date: date_range.last,
        uploads: uploads,
        storage: storage
      )

    redirect_to =
      Routes.site_path(socket, :settings_imports_exports, URI.encode_www_form(site.domain))

    {:noreply, redirect(socket, external: redirect_to)}
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
    tables = Plausible.Imported.tables()
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
    clamped_date_range = clamp_date_range(socket, original_date_range)

    all_uploaded? = completed != [] and in_progress == []
    can_confirm? = all_uploaded? && clamped_date_range

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

  defp clamp_date_range(socket, %Date.Range{first: start_date, last: end_date}) do
    %{occupied_ranges: occupied_ranges, cutoff_date: cutoff_date} = socket.assigns
    end_date = Enum.min([end_date, cutoff_date], Date)

    if Date.diff(end_date, start_date) >= 2 do
      free_ranges = find_free_ranges(start_date, end_date, occupied_ranges)

      unless Enum.empty?(free_ranges) do
        Enum.max_by(free_ranges, &Date.diff(&1.last, &1.first))
      end
    end
  end

  defp find_free_ranges(start_date, end_date, occupied_ranges) do
    free_ranges(Date.range(start_date, end_date), start_date, occupied_ranges, [])
  end

  # This function recursively finds open ranges that are not yet occupied
  # by existing imported data. The idea is that we keep moving a dynamic
  # date index `d` from start until the end of `imported_range`, hopping
  # over each occupied range, and capturing the open ranges step-by-step
  # in the `result` array.
  defp free_ranges(import_range, d, [occupied_range | rest_of_occupied_ranges], result) do
    cond do
      Date.diff(occupied_range.last, d) <= 0 ->
        free_ranges(import_range, d, rest_of_occupied_ranges, result)

      in_range?(d, occupied_range) || Date.diff(occupied_range.first, d) < 2 ->
        d = occupied_range.last
        free_ranges(import_range, d, rest_of_occupied_ranges, result)

      true ->
        free_range = Date.range(d, occupied_range.first)
        result = result ++ [free_range]
        d = occupied_range.last
        free_ranges(import_range, d, rest_of_occupied_ranges, result)
    end
  end

  defp free_ranges(import_range, d, [], result) do
    if Date.diff(import_range.last, d) < 2 do
      result
    else
      result ++ [Date.range(d, import_range.last)]
    end
  end

  defp in_range?(date, range) do
    Date.before?(range.first, date) && Date.after?(range.last, date)
  end
end
