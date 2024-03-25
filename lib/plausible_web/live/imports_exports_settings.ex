defmodule PlausibleWeb.Live.ImportsExportsSettings do
  @moduledoc """
  LiveView allowing listing and deleting imports.
  """
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  import PlausibleWeb.Components.Generic
  import PlausibleWeb.TextHelpers

  alias Plausible.Imported
  alias Plausible.Imported.SiteImport
  alias Plausible.Sites

  require Plausible.Imported.SiteImport

  def mount(
        _params,
        %{"domain" => domain, "current_user_id" => user_id},
        socket
      ) do
    socket =
      socket
      |> assign_new(:site, fn ->
        Sites.get_for_user!(user_id, domain, [:owner, :admin, :super_admin])
      end)
      |> assign_new(:site_imports, fn %{site: site} ->
        site
        |> Imported.list_all_imports()
        |> Enum.map(&%{site_import: &1, live_status: &1.status})
      end)
      |> assign_new(:pageview_counts, fn %{site: site} ->
        Plausible.Stats.Clickhouse.imported_pageview_counts(site)
      end)
      |> assign_new(:current_user, fn ->
        Plausible.Repo.get(Plausible.Auth.User, user_id)
      end)

    :ok = Imported.listen()

    {:ok, assign(socket, max_imports: Imported.max_complete_imports())}
  end

  def render(assigns) do
    ~H"""
    <header class="relative border-b border-gray-200 pb-4">
      <h3 class="mt-8 text-md leading-6 font-medium text-gray-900 dark:text-gray-100">
        Existing Imports
      </h3>
      <p class="mt-1 text-sm leading-5 text-gray-500 dark:text-gray-200">
        A maximum of <%= @max_imports %> imports at any time is allowed.
      </p>
    </header>

    <div
      :if={Enum.empty?(@site_imports)}
      class="text-gray-800 dark:text-gray-200 text-center mt-8 mb-12"
    >
      <p>There are no imports yet for this site.</p>
    </div>
    <ul :if={not Enum.empty?(@site_imports)}>
      <li :for={entry <- @site_imports} class="py-4 flex items-center justify-between space-x-4">
        <div class="flex flex-col">
          <p class="text-sm leading-5 font-medium text-gray-900 dark:text-gray-100">
            <%= Plausible.Imported.SiteImport.label(entry.site_import) %>
            <span :if={entry.live_status == SiteImport.completed()} class="text-xs font-normal">
              (<%= Map.get(@pageview_counts, entry.site_import.id, 0) %> page views)
            </span>
            <Heroicons.clock
              :if={entry.live_status == SiteImport.pending()}
              class="inline-block h-6 w-5 text-indigo-600 dark:text-green-600"
            />
            <.spinner
              :if={entry.live_status == SiteImport.importing()}
              class="inline-block h-6 w-5 text-indigo-600 dark:text-green-600"
            />
            <Heroicons.check
              :if={entry.live_status == SiteImport.completed()}
              class="inline-block h-6 w-5 text-indigo-600 dark:text-green-600"
            />
            <Heroicons.exclamation_triangle
              :if={entry.live_status == SiteImport.failed()}
              class="inline-block h-6 w-5 text-indigo-600 dark:text-green-600"
            />
          </p>
          <p class="text-sm leading-5 text-gray-500 dark:text-gray-200">
            From <%= format_date(entry.site_import.start_date) %> to <%= format_date(
              entry.site_import.end_date
            ) %> (created on <%= format_date(
              entry.site_import.inserted_at || entry.site_import.start_date
            ) %>)
          </p>
        </div>
        <.button
          data-to={"/#{URI.encode_www_form(@site.domain)}/settings/forget-import/#{entry.site_import.id}"}
          theme="danger"
          data-method="delete"
          data-csrf={Plug.CSRFProtection.get_csrf_token()}
          class="sm:ml-3 sm:w-auto w-full"
          data-confirm="Are you sure you want to delete this import?"
        >
          <span :if={entry.live_status in [SiteImport.completed(), SiteImport.failed()]}>
            Delete Import
          </span>
          <span :if={entry.live_status not in [SiteImport.completed(), SiteImport.failed()]}>
            Cancel Import
          </span>
        </.button>
      </li>
    </ul>
    """
  end

  def handle_info({:notification, :analytics_imports_jobs, status}, socket) do
    [{status_str, import_id}] = Enum.to_list(status)
    {site_imports, updated?} = update_imports(socket.assigns.site_imports, import_id, status_str)

    pageview_counts =
      if updated? do
        Plausible.Stats.Clickhouse.imported_pageview_counts(socket.assigns.site)
      else
        socket.assigns.pageview_counts
      end

    {:noreply, assign(socket, site_imports: site_imports, pageview_counts: pageview_counts)}
  end

  defp update_imports(site_imports, import_id, status_str) do
    Enum.map_reduce(site_imports, false, fn
      %{site_import: %{id: ^import_id}} = entry, _changed? ->
        new_status =
          case status_str do
            "complete" -> SiteImport.completed()
            "fail" -> SiteImport.failed()
            "transient_fail" -> SiteImport.importing()
          end

        {%{entry | live_status: new_status}, true}

      entry, changed? ->
        {entry, changed?}
    end)
  end
end
