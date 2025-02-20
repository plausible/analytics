defmodule PlausibleWeb.Live.ImportsExportsSettings do
  @moduledoc """
  LiveView allowing listing and deleting imports.
  """
  use PlausibleWeb, :live_view

  import PlausibleWeb.TextHelpers

  alias Plausible.Imported
  alias Plausible.Imported.SiteImport

  require Plausible.Imported.SiteImport

  def mount(_params, %{"domain" => domain}, socket) do
    socket =
      socket
      |> assign_new(:site, fn %{current_user: current_user} ->
        Plausible.Sites.get_for_user!(current_user, domain, [
          :owner,
          :admin,
          :super_admin
        ])
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

    :ok = Imported.listen()

    {:ok, assign(socket, max_imports: Imported.max_complete_imports())}
  end

  def render(assigns) do
    import_in_progress? =
      Enum.any?(
        assigns.site_imports,
        &(&1.live_status in [SiteImport.pending(), SiteImport.importing()])
      )

    at_maximum? = length(assigns.site_imports) >= assigns.max_imports

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
        import_warning: import_warning
      )

    ~H"""
    <.notice :if={@import_warning} theme={:gray}>
      {@import_warning}
    </.notice>

    <div class="mt-4 flex justify-end gap-x-4">
      <.button_link
        theme="bright"
        href={Plausible.Google.API.import_authorize_url(@site.id)}
        disabled={@import_in_progress? or @at_maximum?}
      >
        Import from
        <img
          src="/images/icon/google_analytics_logo.svg"
          alt="Google Analytics import"
          class="h-6 w-12"
        />
      </.button_link>
      <.button_link
        disabled={@import_in_progress? or @at_maximum?}
        href={"/#{URI.encode_www_form(@site.domain)}/settings/import"}
      >
        Import from CSV
      </.button_link>
    </div>

    <p :if={Enum.empty?(@site_imports)} class="text-center text-sm mt-8 mb-12">
      There are no imports yet for this site.
    </p>

    <div class="mt-8">
      <.table :if={not Enum.empty?(@site_imports)} rows={@site_imports}>
        <:thead>
          <.th>Import</.th>
          <.th hide_on_mobile>Date Range</.th>
          <.th hide_on_mobile>
            <div class="text-right">Pageviews</div>
          </.th>
          <.th invisible>Actions</.th>
        </:thead>

        <:tbody :let={entry}>
          <.td max_width="max-w-40">
            <div class="flex items-center gap-x-2 truncate">
              <div class="w-6" title={notice_message(entry.tooltip)}>
                <Heroicons.clock
                  :if={entry.live_status == SiteImport.pending()}
                  class="block h-6 w-6 text-indigo-600 dark:text-green-600"
                />
                <.spinner
                  :if={entry.live_status == SiteImport.importing()}
                  class="block h-6 w-6 text-indigo-600 dark:text-green-600"
                />
                <Heroicons.check
                  :if={entry.live_status == SiteImport.completed()}
                  class="block h-6 w-6 text-indigo-600 dark:text-green-600"
                />
                <Heroicons.exclamation_triangle
                  :if={entry.live_status == SiteImport.failed()}
                  class="block h-6 w-6 text-red-700 dark:text-red-500"
                />
              </div>
              <div
                class="max-w-sm"
                title={"#{Plausible.Imported.SiteImport.label(entry.site_import)} created at #{format_date(entry.site_import.inserted_at)}"}
              >
                {Plausible.Imported.SiteImport.label(entry.site_import)}
              </div>
            </div>
          </.td>

          <.td hide_on_mobile>
            {format_date(entry.site_import.start_date)} - {format_date(entry.site_import.end_date)}
          </.td>

          <.td>
            <div class="text-right">
              {if entry.live_status == SiteImport.completed(),
                do:
                  PlausibleWeb.StatsView.large_number_format(
                    pageview_count(entry.site_import, @pageview_counts)
                  )}
            </div>
          </.td>
          <.td actions>
            <.delete_button
              href={"/#{URI.encode_www_form(@site.domain)}/settings/forget-import/#{entry.site_import.id}"}
              method="delete"
              data-confirm="Are you sure you want to delete this import?"
            />
          </.td>
        </:tbody>
      </.table>
    </div>
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

  defp notice_message(:slow_import) do
    """
    The import process might be taking longer due to the amount of data
    and rate limiting enforced by Google Analytics.
    """
  end

  defp notice_message(_), do: nil
end
