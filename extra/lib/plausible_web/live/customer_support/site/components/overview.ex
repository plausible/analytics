defmodule PlausibleWeb.CustomerSupport.Site.Components.Overview do
  @moduledoc """
  Site overview component - handles site settings and management
  """
  use PlausibleWeb, :live_component
  import PlausibleWeb.CustomerSupport.Live

  def update(%{site: site}, socket) do
    changeset = Plausible.Site.crm_changeset(site, %{})
    form = to_form(changeset)
    {:ok, assign(socket, site: site, form: form)}
  end

  def render(assigns) do
    ~H"""
    <div class="mt-8">
      <.form :let={f} for={@form} phx-target={@myself} phx-submit="save-site">
        <div class="flex justify-center items-center gap-x-8 pb-8 mb-8 border-b border-gray-200 dark:border-gray-700 w-full text-sm text-center">
          <span>Quick links:</span>

          <.styled_link
            new_tab={true}
            href={stats_path(@site.domain)}
          >
            Dashboard
          </.styled_link>

          <.styled_link
            new_tab={true}
            href={~p"/#{@site.domain}/settings/general"}
          >
            Settings
          </.styled_link>

          <.styled_link
            new_tab={true}
            href={"https://plausible.grafana.net/d/BClBG5b4k/ingest-counters-per-domain?orgId=1&from=now-24h&to=now&timezone=browser&var-domain=#{@site.domain}&refresh=10s"}
          >
            Ingest Overview
          </.styled_link>
        </div>

        <.input
          type="select"
          field={f[:timezone]}
          label="Timezone"
          options={Plausible.Timezones.options()}
        />
        <.input type="checkbox" field={f[:public]} label="Public?" wrapper_class="mt-2" />
        <div class="flex flex-col gap-6 mt-6">
          <.input
            type="datetime-local"
            field={f[:native_stats_start_at]}
            label="Native Stats Start At"
          />
          <.input
            type="text"
            field={f[:ingest_rate_limit_threshold]}
            label="Ingest Rate Limit Threshold"
          />
          <.input
            type="text"
            field={f[:ingest_rate_limit_scale_seconds]}
            label="Ingest Rate Limit Scale Seconds"
          />
        </div>

        <div class="flex justify-between mt-6">
          <.button phx-target={@myself} type="submit">
            Save
          </.button>

          <.button
            phx-target={@myself}
            phx-click="delete-site"
            data-confirm="Are you sure you want to delete this site?"
            theme="danger"
          >
            Delete Site
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  # capability:begin
  # id: cs_update_site@ui_session
  # action: cs_update_site
  # transport: ui_session
  # entry: live /cs/sites/site/:id?tab=overview handle_event "save-site"
  # handler: PlausibleWeb.CustomerSupport.Site.Components.Overview.handle_event/3
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [super_admin]
  # current_role_enforced_by: router pipeline :flags (SuperAdminOnlyPlug) + live_session :customer_support on_mount SuperAdminLiveAuth
  # current_feature_gate: none
  # proposed_scope: cs:write
  # proposed_roles: [super_admin]
  # confidence: verified
  # notes: Site.crm_changeset: timezone, public, native_stats_start_at, ingest rate limit, onboarding_status; public makes the dashboard readable by anyone
  # capability:end
  def handle_event("save-site", %{"site" => params}, socket) do
    site = socket.assigns.site

    case Plausible.Site.crm_changeset(site, params) |> Plausible.Repo.update() do
      {:ok, updated_site} ->
        form = Plausible.Site.crm_changeset(updated_site, %{}) |> to_form()
        success("Site updated successfully")
        {:noreply, assign(socket, site: updated_site, form: form)}

      {:error, changeset} ->
        form = changeset |> to_form()
        failure("Failed to update site")
        {:noreply, assign(socket, form: form)}
    end
  end

  # capability:begin
  # id: cs_delete_site@ui_session
  # action: cs_delete_site
  # transport: ui_session
  # entry: live /cs/sites/site/:id?tab=overview handle_event "delete-site"
  # handler: PlausibleWeb.CustomerSupport.Site.Components.Overview.handle_event/3
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [super_admin]
  # current_role_enforced_by: router pipeline :flags (SuperAdminOnlyPlug) + live_session :customer_support on_mount SuperAdminLiveAuth
  # current_feature_gate: none
  # proposed_scope: cs:delete
  # proposed_roles: [super_admin]
  # confidence: verified
  # notes: Site.Removal.run, irreversible
  # capability:end
  def handle_event("delete-site", _, socket) do
    site = socket.assigns.site

    {:ok, _} = Plausible.Site.Removal.run(site)
    navigate_with_success(~p"/cs", "Site deleted")
    {:noreply, socket}
  end
end
