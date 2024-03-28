defmodule PlausibleWeb.Live.LocalExports do
  @moduledoc """
  LiveView allowing listing and deleting local (i.e. on file system) exports.
  """
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  import PlausibleWeb.Components.Generic
  alias Plausible.Exports

  @impl true
  def mount(_params, %{"site_id" => site_id, "domain" => domain, "user_role" => role}, socket) do
    socket =
      socket
      |> assign(site_id: site_id, domain: domain, can_delete?: role in [:owner, :admin])
      |> list_local_exports()

    if connected?(socket) do
      Exports.oban_listen()
    end

    {:ok, socket}
  end

  defp list_local_exports(socket) do
    assign(socket, local_exports: Exports.list_local_exports(socket.assigns.site_id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="border-b border-gray-200 pb-4">
      <h3 class="mt-8 text-md leading-6 font-medium text-gray-900 dark:text-gray-100">
        Existing Exports
      </h3>
    </header>

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
    <% end %>
    """
  end

  @impl true
  def handle_event("delete", %{"path" => path}, socket) do
    File.rm!(path)
    {:noreply, list_local_exports(socket)}
  end

  def handle_event("cancel", %{"job-id" => job_id}, socket) do
    Oban.cancel_job(String.to_integer(job_id))
    {:noreply, list_local_exports(socket)}
  end

  @impl true
  def handle_info({:notification, Exports, _details}, socket) do
    {:noreply, list_local_exports(socket)}
  end

  @format_path_regex ~r/^(?<beginning>((.+?\/){1})).*(?<ending>(\/.*){3})$/

  defp format_path(path) do
    path_string =
      path
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
