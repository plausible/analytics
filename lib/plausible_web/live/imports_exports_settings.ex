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
        |> Enum.map(
          &%{site_import: &1, live_status: &1.status, tooltip: notice_label(&1, &1.status)}
        )
      end)
      |> assign_new(:pageview_counts, fn %{site: site} ->
        Plausible.Stats.Clickhouse.imported_pageview_counts(site)
      end)
      |> assign_new(:current_user, fn ->
        Plausible.Repo.get(Plausible.Auth.User, user_id)
      end)
      |> assign_new(:max_imports, fn %{site: site} ->
        Imported.max_complete_imports(site)
      end)

    :ok = Imported.listen()

    {:ok, socket}
  end

  def render(assigns) do
    import_in_progress? =
      Enum.any?(
        assigns.site_imports,
        &(&1.live_status in [SiteImport.pending(), SiteImport.importing()])
      )

    at_maximum? = length(assigns.site_imports) >= assigns.max_imports

    csv_imports_exports_enabled? = FunWithFlags.enabled?(:csv_imports_exports, for: assigns.site)

    import_warning =
      cond do
        import_in_progress? ->
          "No new imports can be started until the import in progress is completed or cancelled."

        at_maximum? ->
          "Maximum of #{assigns.max_imports} imports is reached. " <>
            "Delete or cancel an existing import to start a new one."

        true ->
          nil
      end

    assigns =
      assign(assigns,
        import_in_progress?: import_in_progress?,
        at_maximum?: at_maximum?,
        import_warning: import_warning,
        csv_imports_exports_enabled?: csv_imports_exports_enabled?
      )

    ~H"""
    <div class="mt-5 flex gap-x-4">
      <.button_link
        class="w-36 h-20"
        theme="bright"
        disabled={@import_in_progress? or @at_maximum?}
        href={Plausible.Google.API.import_authorize_url(@site.id)}
      >
        <img src="/images/icon/google_analytics_logo.svg" alt="Google Analytics import" />
      </.button_link>

      <.button_link
        :if={@csv_imports_exports_enabled?}
        class="w-36 h-20"
        theme="bright"
        disabled={@import_in_progress? or @at_maximum?}
        href={"/#{URI.encode_www_form(@site.domain)}/settings/import"}
      >
        <img class="h-16" src="/images/icon/csv_logo.svg" alt="New CSV import" />
      </.button_link>
    </div>

    <p :if={@import_warning} class="mt-4 text-gray-400 text-sm italic">
      <%= @import_warning %>
    </p>

    <header class="relative border-b border-gray-200 pb-4">
      <h3 class="mt-6 text-md leading-6 font-medium text-gray-900 dark:text-gray-100">
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
              class="inline-block h-6 w-5 text-red-700 dark:text-red-700"
            />
            <span :if={entry.live_status == SiteImport.failed()}>
              Import failed -
            </span>
            <.tooltip :if={entry.tooltip}>
              <%= Plausible.Imported.SiteImport.label(entry.site_import) %>
              <:tooltip_content>
                <.notice_message message_label={entry.tooltip} />
              </:tooltip_content>
            </.tooltip>
            <span :if={!entry.tooltip}>
              <%= Plausible.Imported.SiteImport.label(entry.site_import) %>
            </span>
            <span :if={entry.live_status == SiteImport.completed()} class="text-xs font-normal">
              (<%= PlausibleWeb.StatsView.large_number_format(
                pageview_count(entry.site_import, @pageview_counts)
              ) %> page views)
            </span>
          </p>
          <p class="text-sm leading-5 text-gray-500 dark:text-gray-200">
            From <%= format_date(entry.site_import.start_date) %> to <%= format_date(
              entry.site_import.end_date
            ) %>
            <%= if entry.live_status == SiteImport.completed() do %>
              (imported
            <% else %>
              (started
            <% end %>
            on <%= format_date(entry.site_import.inserted_at) %>)
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
          <span :if={entry.live_status == SiteImport.completed()}>
            Delete Import
          </span>
          <span :if={entry.live_status == SiteImport.failed()}>
            Discard
          </span>
          <span :if={entry.live_status not in [SiteImport.completed(), SiteImport.failed()]}>
            Cancel Import
          </span>
        </.button>
      </li>
    </ul>
    """
  end

  def handle_info({:notification, :analytics_imports_jobs, details}, socket) do
    {site_imports, updated?} =
      update_imports(socket.assigns.site_imports, details["import_id"], details["event"])

    pageview_counts =
      if updated? do
        Plausible.Stats.Clickhouse.imported_pageview_counts(socket.assigns.site)
      else
        socket.assigns.pageview_counts
      end

    {:noreply, assign(socket, site_imports: site_imports, pageview_counts: pageview_counts)}
  end

  defp pageview_count(site_import, pageview_counts) do
    count = Map.get(pageview_counts, site_import.id, 0)

    if site_import.legacy do
      count + Map.get(pageview_counts, 0, 0)
    else
      count
    end
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

        {%{entry | live_status: new_status, tooltip: notice_label(entry.site_import, new_status)},
         true}

      entry, changed? ->
        {entry, changed?}
    end)
  end

  defp notice_label(site_import, status) do
    now = NaiveDateTime.utc_now()
    seconds_since_update = NaiveDateTime.diff(now, site_import.updated_at, :second)
    in_progress? = status in [SiteImport.pending(), SiteImport.importing()]

    if in_progress? and seconds_since_update >= 300 do
      :slow_import
    end
  end

  defp notice_message(%{message_label: :slow_import} = assigns) do
    ~H"""
    The import process might be taking longer due to the amount of data<br />
    and rate limiting enforced by Google Analytics.
    """
  end

  defp notice_message(_), do: nil
end
