defmodule PlausibleWeb.Live.CSVExport do
  @moduledoc """
  LiveView allowing scheduling, watching, downloading, and deleting S3 and local exports.
  """
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  import PlausibleWeb.Components.Generic
  alias Plausible.Exports

  @impl true
  def mount(_params, session, socket) do
    %{
      "site_id" => site_id,
      "site_timezone" => site_timezone,
      "site_domain" => site_domain
    } = session

    socket =
      socket
      |> assign(site: %{id: site_id, domain: site_domain, timezone: site_timezone})
      |> fetch_export()

    if connected?(socket) do
      Exports.oban_listen()
    end

    {:ok, socket}
  end

  defp fetch_export(socket) do
    %{site: %{id: site_id}} = socket.assigns
    s3_bucket = Plausible.S3.exports_bucket()
    s3_key = Exports.s3_export_object(site_id)

    s3_export =
      case ExAws.request!(ExAws.S3.head_object(s3_bucket, s3_key)) do
        %{status: 404} ->
          nil

        %{headers: headers} ->
          size = nil
          created_on = nil
          download_url = nil
          %{size: size, created_on: created_on, download_url: download_url}
      end

    assign(socket, export: s3_export)
  end

  defp fetch_export(socket) do
    %{site: %{id: site_id, timezone: site_timezone}} = socket.assigns
    local_path = Exports.local_export_file(site_id)

    local_export =
      if File.exists?(local_path) do
        # TODO
        %File.Stat{size: size, ctime: ctime} = File.stat!(local_path, time: :posix)

        local_created_on =
          DateTime.from_unix!(ctime)
          |> Plausible.Timezones.to_datetime_in_timezone(site_timezone)
          |> DateTime.to_date()

        %{size: size, created_on: local_created_on}
      end

    assign(socket, export: local_export)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- <header class="border-b border-gray-200 pb-4">
      <h3 class="mt-8 text-md leading-6 font-medium text-gray-900 dark:text-gray-100">
        Existing Exports
      </h3>
    </header>

    <div class="mt-4">
    <PlausibleWeb.Components.Generic.button
      data-method="post"
      data-to={"/#{URI.encode_www_form(@site.domain)}/settings/export"}
      data-csrf={Plug.CSRFProtection.get_csrf_token()}
    >
      Export to CSV
    </PlausibleWeb.Components.Generic.button>
    </div>

    <%= if Enum.empty?(@local_exports) do %>
      <div class="text-gray-800 dark:text-gray-200 text-center mt-8 mb-12">
        <p>There are no exports yet for this site.</p>
      </div>
    <% else %>
      <ul id="local-exports">
        <li
          :for={local_export <- @local_exports}
          id={local_export.path}
          class="flex items-center justify-between"
        >
          <div class="flex flex-col" {if(err = local_export.last_error, do: %{title: err}, else: %{})}>
            <div class="flex items-center">
              <Heroicons.clock
                :if={local_export.state in ["scheduled", "available", "retryable"]}
                micro
                class="h-4 w-4 text-indigo-600 dark:text-green-600"
              />
              <.spinner
                :if={local_export.state == "executing"}
                class="h-4 w-4 text-indigo-600 dark:text-green-600"
              />
              <Heroicons.check
                :if={local_export.state == "completed"}
                micro
                class="h-4 w-4 text-indigo-600 dark:text-green-600"
              />
              <Heroicons.exclamation_triangle
                :if={local_export.state in ["discarded", "cancelled"]}
                micro
                class="h-4 w-4 text-indigo-600 dark:text-green-600"
              />

              <a
                :if={local_export.state == "completed"}
                href={
                  Routes.site_path(
                    PlausibleWeb.Endpoint,
                    :download_local_export,
                    @domain,
                    Path.basename(local_export.path)
                  )
                }
                class="inline-block text-indigo-600 hover:underline underline-offset-2"
              >
                <span class="ml-2 text-xs font-normal">
                  <span title={local_export.path}>
                    <%= format_path(local_export.path) %>
                  </span>
                  <span :if={local_export.size} title={local_export.size}>
                    (<%= format_bytes(local_export.size) %>)
                  </span>
                </span>
              </a>

              <span :if={local_export.state != "completed"} class="ml-2 text-xs font-normal">
                <span title={local_export.path}>
                  <%= format_path(local_export.path) %>
                </span>
              </span>
            </div>
          </div>
          <div class="ml-3 flex items-center">
            <button
              :if={@can_delete? and local_export.state == "completed"}
              phx-click="delete"
              phx-value-path={local_export.path}
              data-confirm="Are you sure you want to delete this export?"
              class="text-red-600"
            >
              <Heroicons.trash micro class="w-4 h-4 text-red-600" />
            </button>
            <button
              :if={
                @can_delete? and
                  local_export.state in ["scheduled", "available", "retryable", "executing"]
              }
              phx-click="cancel"
              phx-value-job-id={local_export.job_id}
              data-confirm="Are you sure you want to cancel this export?"
              class="text-red-600"
            >
              <Heroicons.x_circle micro class="w-4 h-4 text-red-600" />
            </button>
          </div>
        </li>
      </ul>
    <% end %> --%>
    """
  end

  @impl true
  def handle_event("export", _params, socket) do
    %{site: site, current_user: user} = conn.assigns

    socket =
      if date_range = Exports.date_range(site.id) do
        # TODO use site.stats_start_date for date_range?
        case Exports.schedule_export(site, user, date_range) do
          {:ok, _job} ->
            put_flash(socket, :success, "EXPORT SCHEDULED")

          {:error, :already_scheduled} ->
            put_flash(socket, :error, "ANOTHER EXPORT ALREADY SCHEDULED")

          {:error, :rate_limit} ->
            put_flash(socket, :error, "EXPORT NOT SCHEDULED. TOO MANY TODAY")
        end
      else
        put_flash(socket, :error, "NO DATA TO EXPORT")
      end

    redirect(socket, external: Routes.site_path(socket, :settings_imports_exports, site.domain))
  end

  @impl true
  def handle_info({:notification, Exports, %{"site_id" => site_id} = details}, socket) do
    socket =
      if site_id == socket.assigns.site_id do
        fetch_local_export(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= memory_unit("TiB") -> format_bytes(bytes, "TiB")
      bytes >= memory_unit("GiB") -> format_bytes(bytes, "GiB")
      bytes >= memory_unit("MiB") -> format_bytes(bytes, "MiB")
      bytes >= memory_unit("KiB") -> format_bytes(bytes, "KiB")
      true -> format_bytes(bytes, "B")
    end
  end

  defp format_bytes(bytes, "B"), do: "#{bytes} B"

  defp format_bytes(bytes, unit) do
    value = bytes / memory_unit(unit)
    "#{:erlang.float_to_binary(value, decimals: 1)} #{unit}"
  end

  defp memory_unit("TiB"), do: 1024 * 1024 * 1024 * 1024
  defp memory_unit("GiB"), do: 1024 * 1024 * 1024
  defp memory_unit("MiB"), do: 1024 * 1024
  defp memory_unit("KiB"), do: 1024
end
