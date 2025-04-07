defmodule PlausibleWeb.Live.CSVExport do
  @moduledoc """
  LiveView allowing scheduling, watching, downloading, and deleting S3 and local exports.
  """
  use PlausibleWeb, :live_view

  alias Plausible.Exports

  # :not_mounted_at_router ensures we have already done auth checks in the controller
  # if this liveview becomes available from the router, please make sure
  # to check that site_role is allowed to manage site exports
  @impl true
  def mount(:not_mounted_at_router, session, socket) do
    %{
      "storage" => storage,
      "site_id" => site_id,
      "email_to" => email_to
    } = session

    socket =
      socket
      |> assign(site_id: site_id, email_to: email_to, storage: storage)
      |> assign_new(:site, fn -> Plausible.Repo.get!(Plausible.Site, site_id) end)
      |> fetch_export()

    if connected?(socket) do
      Exports.oban_listen()
    end

    {:ok, socket}
  end

  defp fetch_export(socket) do
    %{storage: storage, site_id: site_id} = socket.assigns

    get_export =
      case storage do
        "s3" ->
          &Exports.get_s3_export!/1

        "local" ->
          %{domain: domain, timezone: timezone} = socket.assigns.site
          &Exports.get_local_export(&1, domain, timezone)
      end

    socket = assign(socket, export: nil)

    if job = Exports.get_last_export_job(site_id) do
      %Oban.Job{state: state} = job

      case state do
        _ when state in ["scheduled", "available", "retryable"] ->
          assign(socket, status: "in_progress")

        "executing" ->
          # Exports.oban_notify/1 is called in `perform/1` and
          # the notification arrives while the job.state is still "executing"
          if export = get_export.(site_id) do
            assign(socket, status: "ready", export: export)
          else
            assign(socket, status: "in_progress")
          end

        "completed" ->
          if export = get_export.(site_id) do
            assign(socket, status: "ready", export: export)
          else
            assign(socket, status: "can_schedule")
          end

        "discarded" ->
          assign(socket, status: "export_failed")

        "cancelled" ->
          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          if export = get_export.(site_id) do
            assign(socket, status: "ready", export: export)
          else
            assign(socket, status: "can_schedule")
          end
      end
    else
      if export = get_export.(site_id) do
        assign(socket, status: "ready", export: export)
      else
        assign(socket, status: "can_schedule")
      end
    end
  rescue
    _e ->
      assign(socket, status: "fetch_error", export: nil)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= case @status do %>
      <% "can_schedule" -> %>
        <.prepare_download />
      <% "in_progress" -> %>
        <.in_progress />
      <% "export_failed" -> %>
        <.export_failed />
      <% "fetch_error" -> %>
        <.fetch_export_failed />
      <% "ready" -> %>
        <.download
          storage={@storage}
          export={@export}
          href={Routes.site_path(@socket, :download_export, @site.domain)}
        />
    <% end %>
    """
  end

  defp prepare_download(assigns) do
    ~H"""
    <p class="text-sm">
      Prepare your data for download by clicking the button below. When that's done, a Zip file that you can download will appear.
    </p>
    <.button phx-click="export">Prepare download</.button>
    """
  end

  defp in_progress(assigns) do
    ~H"""
    <div class="flex items-center justify-between space-x-2">
      <div class="flex items-center">
        <.spinner />
        <span class="ml-2 text-sm">We are preparing your download ...</span>
      </div>
      <button
        phx-click="cancel"
        class="text-red-500 font-semibold text-sm"
        data-confirm="Are you sure you want to cancel this export?"
      >
        Cancel
      </button>
    </div>
    <p class="text-sm mt-4">
      The preparation of your stats might take a while. Depending on the volume of your data, it might take up to 20 minutes. Feel free to leave the page and return later.
    </p>
    """
  end

  defp fetch_export_failed(assigns) do
    ~H"""
    <.notice title="Something went wrong when fetching exports" theme={:red}>
      Please try again later.
    </.notice>
    """
  end

  defp export_failed(assigns) do
    ~H"""
    <div class="flex items-center">
      <Heroicons.exclamation_circle class="w-4 h-4 text-red-500" />
      <p class="ml-2 text-sm">
        Something went wrong when preparing your download. Please
        <button phx-click="export" class="text-indigo-500">try again.</button>
      </p>
    </div>
    """
  end

  defp download(assigns) do
    ~H"""
    <.table rows={[@export]}>
      <:thead>
        <.th>Export</.th>
        <.th invisible>Actions</.th>
      </:thead>
      <:tbody :let={export}>
        <.td>
          <.styled_link href={@href}>
            {export.name}
          </.styled_link>
        </.td>
        <.td actions>
          <.delete_button
            phx-click="delete"
            data-confirm="Are you sure you want to delete this export?"
          />
        </.td>
      </:tbody>
    </.table>

    <p :if={@export.expires_at} class="text-sm">
      Note: this file will expire
      <.hint message={@export.expires_at}>
        {Timex.Format.DateTime.Formatters.Relative.format!(@export.expires_at, "{relative}")}.
      </.hint>
    </p>

    <p :if={@storage == "local"} class="text-sm">
      Located at
      <.hint message={@export.path}>{format_path(@export.path)}</.hint>
      ({format_bytes(@export.size)})
    </p>
    """
  end

  defp hint(assigns) do
    ~H"""
    <span title={@message} class="underline cursor-help underline-offset-2 decoration-dashed">
      {render_slot(@inner_block)}
    </span>
    """
  end

  @impl true
  def handle_event("export", _params, socket) do
    %{storage: storage, site_id: site_id, email_to: email_to} =
      socket.assigns

    schedule_result =
      case storage do
        "s3" -> Exports.schedule_s3_export(site_id, email_to)
        "local" -> Exports.schedule_local_export(site_id, email_to)
      end

    socket =
      case schedule_result do
        {:ok, _job} ->
          fetch_export(socket)

        {:error, :no_data} ->
          socket
          |> put_flash(:error, "There is no data to export")
          |> redirect(
            external:
              Routes.site_path(socket, :settings_imports_exports, socket.assigns.site.domain)
          )
      end

    {:noreply, socket}
  end

  def handle_event("cancel", _params, socket) do
    if job = Exports.get_last_export_job(socket.assigns.site_id), do: Oban.cancel_job(job)
    {:noreply, fetch_export(socket)}
  end

  def handle_event("delete", _params, socket) do
    %{storage: storage, site_id: site_id} = socket.assigns

    case storage do
      "s3" -> Exports.delete_s3_export!(site_id)
      "local" -> Exports.delete_local_export(site_id)
    end

    {:noreply, fetch_export(socket)}
  end

  @impl true
  def handle_info({:notification, Exports, %{"site_id" => site_id}}, socket) do
    socket =
      if site_id == socket.assigns.site_id do
        fetch_export(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  @format_path_regex ~r/^(?<beginning>((.+?\/){3})).*(?<ending>(\/.*){3})$/

  defp format_path(path) do
    path_string =
      path
      |> to_string()
      |> String.replace_prefix("\"", "")
      |> String.replace_suffix("\"", "")

    case Regex.named_captures(@format_path_regex, path_string) do
      %{"beginning" => beginning, "ending" => ending} -> "#{beginning}...#{ending}"
      _ -> path_string
    end
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
