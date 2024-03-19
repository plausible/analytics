defmodule PlausibleWeb.Live.CSVImport do
  use PlausibleWeb, :live_view
  alias Plausible.Imported.CSVImporter

  @impl true
  def mount(_params, session, socket) do
    %{"site_id" => site_id, "user_id" => user_id} = session

    socket =
      socket
      |> assign(site_id: site_id, user_id: user_id)
      |> allow_upload(:import,
        accept: ~w[.csv],
        auto_upload: true,
        max_entries: length(Plausible.Imported.tables()),
        max_file_size: _1GB = 1_000_000_000,
        external: &presign_upload/2,
        progress: &handle_progress/3
      )
      |> process_imported_tables()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <form action="#" method="post" phx-change="validate-upload-form" phx-submit="submit-upload-form">
        <.csv_picker upload={@uploads.import} imported_tables={@imported_tables} />
        <.confirm_button date_range={@date_range} can_confirm?={@can_confirm?} />

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
      class="block border-2 dark:border-gray-600 rounded p-4 hover:border-indigo-300 dark:hover:border-indigo-600 transition cursor-pointer"
    >
      <div class="flex items-center">
        <div class="bg-indigo-200 dark:bg-indigo-700 rounded p-1 hover:bg-indigo-300 dark:hover:bg-indigo-600 transition cursor-pointer">
          <Heroicons.plus class="w-4 h-4" />
        </div>
        <span class="ml-2 text-sm text-gray-600 dark:text-gray-500">
          (or drag-and-drop here)
        </span>
        <.live_file_input upload={@upload} class="hidden" />
      </div>

      <div id="imported-tables" class="mt-5 mb-1 space-y-1">
        <.imported_table
          :for={{table, upload} <- @imported_tables}
          table={table}
          upload={upload}
          errors={if(upload, do: upload_errors(@upload, upload), else: [])}
        />
      </div>
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
    <div id={@table} class="ml-1">
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
    </div>
    """
  end

  @impl true
  def handle_event("validate-upload-form", _params, socket) do
    {:noreply, process_imported_tables(socket)}
  end

  def handle_event("submit-upload-form", _params, socket) do
    %{site_id: site_id, user_id: user_id, date_range: date_range} = socket.assigns
    site = Plausible.Repo.get!(Plausible.Site, site_id)
    user = Plausible.Repo.get!(Plausible.Auth.User, user_id)

    uploads =
      consume_uploaded_entries(socket, :import, fn meta, entry ->
        {:ok, %{"s3_url" => meta.s3_url, "filename" => entry.client_name}}
      end)

    {:ok, _job} =
      CSVImporter.new_import(site, user,
        start_date: date_range.first,
        end_date: date_range.last,
        uploads: uploads
      )

    {:noreply,
     redirect(socket,
       to: Routes.site_path(socket, :settings_imports_exports, URI.encode_www_form(site.domain))
     )}
  end

  defp error_to_string(:too_large), do: "is too large (max size is 1 gigabyte)"
  defp error_to_string(:too_many_files), do: "too many files"
  defp error_to_string(:not_accepted), do: "unacceptable file types"
  defp error_to_string(:external_client_failure), do: "browser upload failed"

  defp presign_upload(entry, socket) do
    %{s3_url: s3_url, presigned_url: upload_url} =
      Plausible.S3.import_presign_upload(socket.assigns.site_id, entry.client_name)

    {:ok, %{uploader: "S3", s3_url: s3_url, url: upload_url}, socket}
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

    date_range = CSVImporter.date_range(Enum.map(valid_uploads, & &1.client_name))
    all_uploaded? = completed != [] and in_progress == []

    socket
    |> cancel_uploads(invalid_uploads)
    |> cancel_uploads(replaced_uploads)
    |> assign(
      imported_tables: imported_tables,
      can_confirm?: all_uploaded?,
      date_range: date_range
    )
  end

  defp cancel_uploads(socket, uploads) do
    Enum.reduce(uploads, socket, fn upload, socket ->
      cancel_upload(socket, :import, upload.ref)
    end)
  end
end
