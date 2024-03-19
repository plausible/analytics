defmodule PlausibleWeb.SiteController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Sites
  alias Plausible.Billing.Quota

  plug(PlausibleWeb.RequireAccountPlug)

  plug(
    PlausibleWeb.AuthorizeSiteAccess,
    [:owner, :admin, :super_admin] when action not in [:new, :create_site]
  )

  def new(conn, _params) do
    current_user = conn.assigns[:current_user]

    render(conn, "new.html",
      changeset: Plausible.Site.changeset(%Plausible.Site{}),
      first_site?: Quota.site_usage(current_user) == 0,
      site_limit: Quota.site_limit(current_user),
      site_limit_exceeded?: Quota.ensure_can_add_new_site(current_user) != :ok,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def create_site(conn, %{"site" => site_params}) do
    user = conn.assigns[:current_user]
    first_site? = Quota.site_usage(user) == 0

    case Sites.create(user, site_params) do
      {:ok, %{site: site}} ->
        if first_site? do
          PlausibleWeb.Email.welcome_email(user)
          |> Plausible.Mailer.send()
        end

        conn
        |> put_session(site.domain <> "_offer_email_report", true)
        |> redirect(external: Routes.site_path(conn, :add_snippet, site.domain))

      {:error, {:over_limit, limit}} ->
        render(conn, "new.html",
          changeset: Plausible.Site.changeset(%Plausible.Site{}),
          first_site?: first_site?,
          site_limit: limit,
          site_limit_exceeded?: true,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      {:error, _, changeset, _} ->
        render(conn, "new.html",
          changeset: changeset,
          first_site?: first_site?,
          site_limit: Quota.site_limit(user),
          site_limit_exceeded?: false,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def add_snippet(conn, _params) do
    user = conn.assigns[:current_user]
    site = conn.assigns[:site]

    is_first_site =
      !Repo.exists?(
        from(sm in Plausible.Site.Membership,
          where:
            sm.user_id == ^user.id and
              sm.site_id != ^site.id
        )
      )

    conn
    |> render("snippet.html",
      site: site,
      skip_plausible_tracking: true,
      is_first_site: is_first_site,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def update_feature_visibility(conn, %{
        "setting" => setting,
        "r" => "/" <> _ = redirect_path,
        "set" => value
      })
      when setting in ~w[conversions_enabled funnels_enabled props_enabled] and
             value in ["true", "false"] do
    site = conn.assigns[:site]
    toggle_field = String.to_existing_atom(setting)

    feature_mod =
      Enum.find(Plausible.Billing.Feature.list(), &(&1.toggle_field() == toggle_field))

    case feature_mod.toggle(site, override: value == "true") do
      {:ok, updated_site} ->
        message =
          if Map.fetch!(updated_site, toggle_field) do
            "#{feature_mod.display_name()} are now visible again on your dashboard"
          else
            "#{feature_mod.display_name()} are now hidden from your dashboard"
          end

        conn
        |> put_flash(:success, message)
        |> redirect(to: redirect_path)

      {:error, _} ->
        conn
        |> put_flash(
          :error,
          "Something went wrong. Failed to toggle #{feature_mod.display_name()} on your dashboard."
        )
        |> redirect(to: redirect_path)
    end
  end

  def settings(conn, %{"website" => website}) do
    redirect(conn, to: Routes.site_path(conn, :settings_general, website))
  end

  def settings_general(conn, _params) do
    site = conn.assigns[:site]

    conn
    |> render("settings_general.html",
      site: site,
      changeset: Plausible.Site.changeset(site, %{}),
      dogfood_page_path: "/:dashboard/settings/general",
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_people(conn, _params) do
    site =
      conn.assigns[:site]
      |> Repo.preload(memberships: :user, invitations: [])

    conn
    |> render("settings_people.html",
      site: site,
      dogfood_page_path: "/:dashboard/settings/people",
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_visibility(conn, _params) do
    site = conn.assigns[:site]
    shared_links = Repo.all(from(l in Plausible.Site.SharedLink, where: l.site_id == ^site.id))

    conn
    |> render("settings_visibility.html",
      site: site,
      shared_links: shared_links,
      dogfood_page_path: "/:dashboard/settings/visibility",
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_goals(conn, _params) do
    site = Repo.preload(conn.assigns[:site], [:owner])
    owner = Plausible.Users.with_subscription(site.owner)
    site = Map.put(site, :owner, owner)

    conn
    |> render("settings_goals.html",
      site: site,
      dogfood_page_path: "/:dashboard/settings/goals",
      connect_live_socket: true,
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_funnels(conn, _params) do
    site = Repo.preload(conn.assigns[:site], [:owner])
    owner = Plausible.Users.with_subscription(site.owner)
    site = Map.put(site, :owner, owner)

    conn
    |> render("settings_funnels.html",
      site: site,
      dogfood_page_path: "/:dashboard/settings/funnels",
      connect_live_socket: true,
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_props(conn, _params) do
    site = Repo.preload(conn.assigns[:site], [:owner])
    owner = Plausible.Users.with_subscription(site.owner)
    site = Map.put(site, :owner, owner)

    conn
    |> render("settings_props.html",
      site: site,
      dogfood_page_path: "/:dashboard/settings/properties",
      layout: {PlausibleWeb.LayoutView, "site_settings.html"},
      connect_live_socket: true
    )
  end

  def settings_email_reports(conn, _params) do
    site = conn.assigns[:site]

    conn
    |> render("settings_email_reports.html",
      site: site,
      weekly_report: Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id),
      monthly_report: Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id),
      spike_notification: Repo.get_by(Plausible.Site.SpikeNotification, site_id: site.id),
      dogfood_page_path: "/:dashboard/settings/email-reports",
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_danger_zone(conn, _params) do
    site = conn.assigns[:site]

    conn
    |> render("settings_danger_zone.html",
      site: site,
      dogfood_page_path: "/:dashboard/settings/danger-zone",
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_integrations(conn, _params) do
    site =
      conn.assigns.site
      |> Repo.preload([:google_auth])

    search_console_domains =
      if site.google_auth do
        Plausible.Google.API.fetch_verified_properties(site.google_auth)
      end

    imported_pageviews =
      if site.imported_data do
        Plausible.Stats.Clickhouse.imported_pageview_count(site)
      else
        0
      end

    has_plugins_tokens? = Plausible.Plugins.API.Tokens.any?(site)

    conn
    |> render("settings_integrations.html",
      site: site,
      imported_pageviews: imported_pageviews,
      has_plugins_tokens?: has_plugins_tokens?,
      search_console_domains: search_console_domains,
      dogfood_page_path: "/:dashboard/settings/integrations",
      connect_live_socket: true,
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_shields(conn, %{"shield" => shield})
      when shield in ["ip_addresses", "countries"] do
    site = conn.assigns.site

    conn
    |> render("settings_shields.html",
      site: site,
      shield: shield,
      dogfood_page_path: "/:dashboard/settings/shields/#{shield}",
      connect_live_socket: true,
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_imports_exports(conn, _params) do
    site = conn.assigns.site

    if FunWithFlags.enabled?(:imports_exports, for: site) do
      conn
      |> render("settings_imports_exports.html",
        site: site,
        dogfood_page_path: "/:dashboard/settings/imports-exports",
        connect_live_socket: true,
        layout: {PlausibleWeb.LayoutView, "site_settings.html"}
      )
    else
      conn
      |> redirect(external: Routes.site_path(conn, :settings, site.domain))
    end
  end

  def update_google_auth(conn, %{"google_auth" => attrs}) do
    site = conn.assigns[:site] |> Repo.preload(:google_auth)

    Plausible.Site.GoogleAuth.set_property(site.google_auth, attrs)
    |> Repo.update!()

    conn
    |> put_flash(:success, "Google integration saved successfully")
    |> redirect(external: Routes.site_path(conn, :settings_integrations, site.domain))
  end

  def delete_google_auth(conn, _params) do
    site =
      conn.assigns[:site]
      |> Repo.preload(:google_auth)

    Repo.delete!(site.google_auth)

    conn = put_flash(conn, :success, "Google account unlinked from Plausible")

    redirect(conn, external: Routes.site_path(conn, :settings_integrations, site.domain))
  end

  def update_settings(conn, %{"site" => site_params}) do
    site = conn.assigns[:site]
    changeset = Plausible.Site.update_changeset(site, site_params)

    case Repo.update(changeset) do
      {:ok, site} ->
        site_session_key = "authorized_site__" <> site.domain

        conn
        |> put_session(site_session_key, nil)
        |> put_flash(:success, "Your site settings have been saved")
        |> redirect(external: Routes.site_path(conn, :settings_general, site.domain))

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Could not update your site settings")
        |> render("settings_general.html",
          site: site,
          changeset: changeset,
          layout: {PlausibleWeb.LayoutView, "site_settings.html"}
        )
    end
  end

  def reset_stats(conn, _params) do
    site = conn.assigns[:site]
    Plausible.Purge.reset!(site)

    conn
    |> put_flash(:success, "#{site.domain} stats will be reset in a few minutes")
    |> redirect(external: Routes.site_path(conn, :settings_danger_zone, site.domain))
  end

  def delete_site(conn, _params) do
    site = conn.assigns[:site]

    Plausible.Site.Removal.run(site.domain)

    conn
    |> put_flash(:success, "Your site and page views deletion process has started.")
    |> redirect(to: "/sites")
  end

  def make_public(conn, _params) do
    site =
      conn.assigns[:site]
      |> Plausible.Site.make_public()
      |> Repo.update!()

    conn
    |> put_flash(:success, "Stats for #{site.domain} are now public.")
    |> redirect(external: Routes.site_path(conn, :settings_visibility, site.domain))
  end

  def make_private(conn, _params) do
    site =
      conn.assigns[:site]
      |> Plausible.Site.make_private()
      |> Repo.update!()

    conn
    |> put_flash(:success, "Stats for #{site.domain} are now private.")
    |> redirect(external: Routes.site_path(conn, :settings_visibility, site.domain))
  end

  def enable_weekly_report(conn, _params) do
    site = conn.assigns[:site]

    result =
      Plausible.Site.WeeklyReport.changeset(%Plausible.Site.WeeklyReport{}, %{
        site_id: site.id,
        recipients: [conn.assigns[:current_user].email]
      })
      |> Repo.insert()

    :ok = tolerate_unique_contraint_violation(result, "weekly_reports_site_id_index")

    conn
    |> put_flash(:success, "You will receive an email report every Monday going forward")
    |> redirect(external: Routes.site_path(conn, :settings_email_reports, site.domain))
  end

  def disable_weekly_report(conn, _params) do
    site = conn.assigns[:site]
    Repo.delete_all(from(wr in Plausible.Site.WeeklyReport, where: wr.site_id == ^site.id))

    conn
    |> put_flash(:success, "You will not receive weekly email reports going forward")
    |> redirect(external: Routes.site_path(conn, :settings_email_reports, site.domain))
  end

  def add_weekly_report_recipient(conn, %{"recipient" => recipient}) do
    site = conn.assigns[:site]

    Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
    |> Plausible.Site.WeeklyReport.add_recipient(recipient)
    |> Repo.update!()

    conn
    |> put_flash(:success, "Added #{recipient} as a recipient for the weekly report")
    |> redirect(external: Routes.site_path(conn, :settings_email_reports, site.domain))
  end

  def remove_weekly_report_recipient(conn, %{"recipient" => recipient}) do
    site = conn.assigns[:site]

    Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
    |> Plausible.Site.WeeklyReport.remove_recipient(recipient)
    |> Repo.update!()

    conn
    |> put_flash(
      :success,
      "Removed #{recipient} as a recipient for the weekly report"
    )
    |> redirect(external: Routes.site_path(conn, :settings_email_reports, site.domain))
  end

  def enable_monthly_report(conn, _params) do
    site = conn.assigns[:site]

    result =
      %Plausible.Site.MonthlyReport{}
      |> Plausible.Site.MonthlyReport.changeset(%{
        site_id: site.id,
        recipients: [conn.assigns[:current_user].email]
      })
      |> Repo.insert()

    :ok = tolerate_unique_contraint_violation(result, "monthly_reports_site_id_index")

    conn
    |> put_flash(:success, "You will receive an email report every month going forward")
    |> redirect(external: Routes.site_path(conn, :settings_email_reports, site.domain))
  end

  def disable_monthly_report(conn, _params) do
    site = conn.assigns[:site]
    Repo.delete_all(from(mr in Plausible.Site.MonthlyReport, where: mr.site_id == ^site.id))

    conn
    |> put_flash(:success, "You will not receive monthly email reports going forward")
    |> redirect(external: Routes.site_path(conn, :settings_email_reports, site.domain))
  end

  def add_monthly_report_recipient(conn, %{"recipient" => recipient}) do
    site = conn.assigns[:site]

    Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
    |> Plausible.Site.MonthlyReport.add_recipient(recipient)
    |> Repo.update!()

    conn
    |> put_flash(:success, "Added #{recipient} as a recipient for the monthly report")
    |> redirect(external: Routes.site_path(conn, :settings_email_reports, site.domain))
  end

  def remove_monthly_report_recipient(conn, %{"recipient" => recipient}) do
    site = conn.assigns[:site]

    Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
    |> Plausible.Site.MonthlyReport.remove_recipient(recipient)
    |> Repo.update!()

    conn
    |> put_flash(
      :success,
      "Removed #{recipient} as a recipient for the monthly report"
    )
    |> redirect(external: Routes.site_path(conn, :settings_email_reports, site.domain))
  end

  def enable_spike_notification(conn, _params) do
    site = conn.assigns[:site]

    res =
      Plausible.Site.SpikeNotification.changeset(%Plausible.Site.SpikeNotification{}, %{
        site_id: site.id,
        threshold: 10,
        recipients: [conn.assigns[:current_user].email]
      })
      |> Repo.insert()

    case res do
      {:ok, _} ->
        conn
        |> put_flash(:success, "You will a notification with traffic spikes going forward")
        |> redirect(external: Routes.site_path(conn, :settings_email_reports, site.domain))

      {:error, _} ->
        conn
        |> put_flash(:error, "Unable to create a spike notification")
        |> redirect(external: Routes.site_path(conn, :settings_email_reports, site.domain))
    end
  end

  def disable_spike_notification(conn, _params) do
    site = conn.assigns[:site]
    Repo.delete_all(from(mr in Plausible.Site.SpikeNotification, where: mr.site_id == ^site.id))

    conn
    |> put_flash(:success, "Spike notification disabled")
    |> redirect(external: Routes.site_path(conn, :settings_email_reports, site.domain))
  end

  def update_spike_notification(conn, %{"spike_notification" => params}) do
    site = conn.assigns[:site]
    notification = Repo.get_by(Plausible.Site.SpikeNotification, site_id: site.id)

    Plausible.Site.SpikeNotification.changeset(notification, params)
    |> Repo.update!()

    conn
    |> put_flash(:success, "Notification settings updated")
    |> redirect(external: Routes.site_path(conn, :settings_email_reports, site.domain))
  end

  def add_spike_notification_recipient(conn, %{"recipient" => recipient}) do
    site = conn.assigns[:site]

    Repo.get_by(Plausible.Site.SpikeNotification, site_id: site.id)
    |> Plausible.Site.SpikeNotification.add_recipient(recipient)
    |> Repo.update!()

    conn
    |> put_flash(:success, "Added #{recipient} as a recipient for the traffic spike notification")
    |> redirect(external: Routes.site_path(conn, :settings_email_reports, site.domain))
  end

  def remove_spike_notification_recipient(conn, %{"recipient" => recipient}) do
    site = conn.assigns[:site]

    Repo.get_by(Plausible.Site.SpikeNotification, site_id: site.id)
    |> Plausible.Site.SpikeNotification.remove_recipient(recipient)
    |> Repo.update!()

    conn
    |> put_flash(
      :success,
      "Removed #{recipient} as a recipient for the monthly report"
    )
    |> redirect(external: Routes.site_path(conn, :settings_email_reports, site.domain))
  end

  def new_shared_link(conn, _params) do
    site = conn.assigns[:site]
    changeset = Plausible.Site.SharedLink.changeset(%Plausible.Site.SharedLink{}, %{})

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("new_shared_link.html",
      site: site,
      changeset: changeset,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def create_shared_link(conn, %{"shared_link" => link}) do
    site = conn.assigns[:site]

    case Sites.create_shared_link(site, link["name"], link["password"]) do
      {:ok, _created} ->
        redirect(conn, external: Routes.site_path(conn, :settings_visibility, site.domain))

      {:error, changeset} ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("new_shared_link.html",
          site: site,
          changeset: changeset,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def edit_shared_link(conn, %{"slug" => slug}) do
    site = conn.assigns[:site]
    shared_link = Repo.get_by(Plausible.Site.SharedLink, slug: slug)
    changeset = Plausible.Site.SharedLink.changeset(shared_link, %{})

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("edit_shared_link.html",
      site: site,
      changeset: changeset,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def update_shared_link(conn, %{"slug" => slug, "shared_link" => params}) do
    site = conn.assigns[:site]
    shared_link = Repo.get_by(Plausible.Site.SharedLink, slug: slug)
    changeset = Plausible.Site.SharedLink.changeset(shared_link, params)

    case Repo.update(changeset) do
      {:ok, _created} ->
        redirect(conn, external: Routes.site_path(conn, :settings_visibility, site.domain))

      {:error, changeset} ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("edit_shared_link.html",
          site: site,
          changeset: changeset,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def delete_shared_link(conn, %{"slug" => slug}) do
    site = conn.assigns[:site]
    site_id = site.id

    case Repo.delete_all(
           from(l in Plausible.Site.SharedLink,
             where: l.slug == ^slug,
             where: l.site_id == ^site_id
           )
         ) do
      {1, _} ->
        conn
        |> put_flash(:success, "Shared Link deleted")
        |> redirect(external: Routes.site_path(conn, :settings_visibility, site.domain))

      {0, _} ->
        conn
        |> put_flash(:error, "Could not find Shared Link")
        |> redirect(external: Routes.site_path(conn, :settings_visibility, site.domain))
    end
  end

  def forget_import(conn, %{"import_id" => import_id}) do
    site = conn.assigns.site

    cond do
      import_id == "0" ->
        Plausible.Purge.delete_imported_stats!(site, 0)

        site
        |> Plausible.Site.remove_imported_data()
        |> Repo.update!()

      site_import = Plausible.Imported.get_import(import_id) ->
        Oban.cancel_all_jobs(
          from(j in Oban.Job,
            where:
              j.queue == "analytics_imports" and
                fragment("(? ->> 'import_id')::int", j.args) == ^site_import.id
          )
        )

        Plausible.Purge.delete_imported_stats!(site_import)

        Plausible.Repo.delete!(site_import)

        if site_import.legacy do
          site
          |> Plausible.Site.remove_imported_data()
          |> Repo.update!()
        end
    end

    conn
    |> put_flash(:success, "Imported data has been cleared")
    |> redirect(external: Routes.site_path(conn, :settings_imports_exports, site.domain))
  end

  def forget_imported(conn, _params) do
    site = conn.assigns.site

    import_ids =
      site
      |> Plausible.Imported.list_all_imports()
      |> Enum.map(& &1.id)

    if import_ids != [] do
      Oban.cancel_all_jobs(
        from(j in Oban.Job,
          where:
            j.queue == "analytics_imports" and
              fragment("(? ->> 'import_id')::int", j.args) in ^import_ids
        )
      )

      Plausible.Purge.delete_imported_stats!(site)

      Plausible.Imported.delete_imports_for_site(site)

      site
      |> Plausible.Site.remove_imported_data()
      |> Repo.update!()
    end

    conn
    |> put_flash(:success, "Imported data has been cleared")
    |> redirect(external: Routes.site_path(conn, :settings_integrations, site.domain))
  end

  def csv_export(conn, _params) do
    %{site: site, current_user: user} = conn.assigns

    Oban.insert!(
      Plausible.Workers.ExportCSV.new(%{
        "site_id" => site.id,
        "email_to" => user.email,
        "s3_bucket" => Plausible.S3.exports_bucket(),
        "s3_path" => "Plausible-#{site.id}.zip"
      })
    )

    conn
    |> put_flash(:success, "SCHEDULED. WAIT FOR MAIL")
    |> redirect(to: Routes.site_path(conn, :settings_imports_exports, site.domain))
  end

  # TODO can it be just a liveview? what to do about layout
  def csv_import(conn, _params) do
    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("csv_import.html",
      layout: {PlausibleWeb.LayoutView, "focus.html"},
      connect_live_socket: true
    )
  end

  def change_domain(conn, _params) do
    changeset = Plausible.Site.update_changeset(conn.assigns.site)

    render(conn, "change_domain.html",
      skip_plausible_tracking: true,
      changeset: changeset,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def change_domain_submit(conn, %{"site" => %{"domain" => new_domain}}) do
    case Plausible.Site.Domain.change(conn.assigns.site, new_domain) do
      {:ok, updated_site} ->
        conn
        |> put_flash(:success, "Website domain changed successfully")
        |> redirect(
          external: Routes.site_path(conn, :add_snippet_after_domain_change, updated_site.domain)
        )

      {:error, changeset} ->
        render(conn, "change_domain.html",
          skip_plausible_tracking: true,
          changeset: changeset,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def add_snippet_after_domain_change(conn, _params) do
    site = conn.assigns[:site]

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("snippet_after_domain_change.html",
      site: site,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  defp tolerate_unique_contraint_violation(result, name) do
    case result do
      {:ok, _} ->
        :ok

      {:error,
       %{
         errors: [
           site_id: {_, [constraint: :unique, constraint_name: ^name]}
         ]
       }} ->
        :ok

      other ->
        other
    end
  end
end
