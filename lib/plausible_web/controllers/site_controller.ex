defmodule PlausibleWeb.SiteController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.{Sites, Goals}

  plug PlausibleWeb.RequireAccountPlug

  plug PlausibleWeb.AuthorizeSiteAccess,
       [:owner, :admin, :super_admin] when action not in [:index, :new, :create_site]

  def index(conn, params) do
    user = conn.assigns[:current_user]

    invitations =
      Repo.all(
        from i in Plausible.Auth.Invitation,
          where: i.email == ^user.email
      )
      |> Repo.preload(:site)

    invitation_site_ids = Enum.map(invitations, & &1.site.id)

    {sites, pagination} =
      Repo.paginate(
        from(s in Plausible.Site,
          join: sm in Plausible.Site.Membership,
          on: sm.site_id == s.id,
          where: sm.user_id == ^user.id,
          where: s.id not in ^invitation_site_ids,
          order_by: s.domain,
          preload: [memberships: sm]
        ),
        params
      )

    user_owns_sites =
      Enum.any?(sites, fn site -> List.first(site.memberships).role == :owner end) ||
        Plausible.Auth.user_owns_sites?(user)

    visitors =
      Plausible.Stats.Clickhouse.last_24h_visitors(sites ++ Enum.map(invitations, & &1.site))

    render(conn, "index.html",
      invitations: invitations,
      sites: sites,
      visitors: visitors,
      pagination: pagination,
      needs_to_upgrade: user_owns_sites && Plausible.Billing.needs_to_upgrade?(user)
    )
  end

  def new(conn, _params) do
    current_user = conn.assigns[:current_user]

    owned_site_count = Plausible.Sites.owned_sites_count(current_user)
    site_limit = Plausible.Billing.sites_limit(current_user)
    is_at_limit = site_limit && owned_site_count >= site_limit
    is_first_site = owned_site_count == 0

    changeset = Plausible.Site.changeset(%Plausible.Site{})

    render(conn, "new.html",
      changeset: changeset,
      is_first_site: is_first_site,
      is_at_limit: is_at_limit,
      site_limit: site_limit,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def create_site(conn, %{"site" => site_params}) do
    user = conn.assigns[:current_user]
    site_count = Plausible.Sites.owned_sites_count(user)
    is_first_site = site_count == 0

    case Sites.create(user, site_params) do
      {:ok, %{site: site}} ->
        if is_first_site do
          PlausibleWeb.Email.welcome_email(user)
          |> Plausible.Mailer.send()
        end

        conn
        |> put_session(site.domain <> "_offer_email_report", true)
        |> redirect(to: Routes.site_path(conn, :add_snippet, site.domain))

      {:error, :limit, limit, _} ->
        render(conn, "new.html",
          changeset: Plausible.Site.changeset(%Plausible.Site{}),
          is_first_site: is_first_site,
          is_at_limit: true,
          site_limit: limit,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      {:error, _, changeset, _} ->
        render(conn, "new.html",
          changeset: changeset,
          is_first_site: is_first_site,
          is_at_limit: false,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def add_snippet(conn, _params) do
    user = conn.assigns[:current_user]
    site = conn.assigns[:site] |> Repo.preload(:custom_domain)

    is_first_site =
      !Repo.exists?(
        from sm in Plausible.Site.Membership,
          where:
            sm.user_id == ^user.id and
              sm.site_id != ^site.id
      )

    conn
    |> render("snippet.html",
      site: site,
      skip_plausible_tracking: true,
      is_first_site: is_first_site,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def new_goal(conn, _params) do
    site = conn.assigns[:site]
    changeset = Plausible.Goal.changeset(%Plausible.Goal{})

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("new_goal.html",
      site: site,
      changeset: changeset,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def create_goal(conn, %{"goal" => goal}) do
    site = conn.assigns[:site]

    case Plausible.Goals.create(site, goal) do
      {:ok, _} ->
        conn
        |> put_flash(:success, "Goal created successfully")
        |> redirect(to: Routes.site_path(conn, :settings_goals, site.domain))

      {:error, changeset} ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("new_goal.html",
          site: site,
          changeset: changeset,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def delete_goal(conn, %{"id" => goal_id}) do
    case Plausible.Goals.delete(goal_id, conn.assigns[:site]) do
      :ok ->
        conn
        |> put_flash(:success, "Goal deleted successfully")
        |> redirect(to: Routes.site_path(conn, :settings_goals, conn.assigns[:site].domain))

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Could not find goal")
        |> redirect(to: Routes.site_path(conn, :settings_goals, conn.assigns[:site].domain))
    end
  end

  @feature_titles %{
    funnels_enabled: "Funnels",
    conversions_enabled: "Goals",
    props_enabled: "Properties"
  }
  def update_feature_visibility(conn, %{
        "setting" => setting,
        "r" => "/" <> _ = redirect_path,
        "set" => value
      })
      when setting in ~w[conversions_enabled funnels_enabled props_enabled] and
             value in ["true", "false"] do
    site = conn.assigns[:site]

    setting = String.to_existing_atom(setting)
    change = Plausible.Site.feature_toggle_change(site, setting, override: value == "true")
    result = Repo.update(change)

    case result do
      {:ok, updated_site} ->
        message =
          if Map.fetch!(updated_site, setting) do
            "#{@feature_titles[setting]} are now visible again on your dashboard"
          else
            "#{@feature_titles[setting]} are now hidden from your dashboard"
          end

        conn
        |> put_flash(:success, message)
        |> redirect(to: redirect_path)

      {:error, _} ->
        conn
        |> put_flash(
          :error,
          "Something went wrong. Failed to toggle #{@feature_titles[setting]} on your dashboard."
        )
        |> redirect(to: redirect_path)
    end
  end

  def settings(conn, %{"website" => website}) do
    redirect(conn, to: Routes.site_path(conn, :settings_general, website))
  end

  def settings_general(conn, _params) do
    site =
      conn.assigns[:site]
      |> Repo.preload([:custom_domain])

    imported_pageviews =
      if site.imported_data do
        Plausible.Stats.Clickhouse.imported_pageview_count(site)
      else
        0
      end

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("settings_general.html",
      site: site,
      imported_pageviews: imported_pageviews,
      changeset: Plausible.Site.changeset(site, %{}),
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_people(conn, _params) do
    site =
      conn.assigns[:site]
      |> Repo.preload(memberships: :user, invitations: [], custom_domain: [])

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("settings_people.html",
      site: site,
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_visibility(conn, _params) do
    site = conn.assigns[:site] |> Repo.preload(:custom_domain)
    shared_links = Repo.all(from l in Plausible.Site.SharedLink, where: l.site_id == ^site.id)

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("settings_visibility.html",
      site: site,
      shared_links: shared_links,
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_goals(conn, _params) do
    site = conn.assigns[:site] |> Repo.preload(:custom_domain)
    goals = Goals.for_site(site, preload_funnels?: true)

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("settings_goals.html",
      site: site,
      goals: goals,
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_funnels(conn, _params) do
    if Plausible.Funnels.enabled_for?(conn.assigns[:current_user]) do
      site = conn.assigns[:site] |> Repo.preload(:custom_domain)

      conn
      |> assign(:skip_plausible_tracking, true)
      |> render("settings_funnels.html",
        site: site,
        layout: {PlausibleWeb.LayoutView, "site_settings.html"}
      )
    else
      conn |> Plug.Conn.put_status(401) |> Plug.Conn.halt()
    end
  end

  def settings_props(conn, _params) do
    if Plausible.Props.enabled_for?(conn.assigns.current_user) do
      conn
      |> assign(:skip_plausible_tracking, true)
      |> render("settings_props.html",
        site: conn.assigns.site,
        layout: {PlausibleWeb.LayoutView, "site_settings.html"}
      )
    else
      conn |> Plug.Conn.put_status(401) |> Plug.Conn.halt()
    end
  end

  def settings_search_console(conn, _params) do
    site =
      conn.assigns[:site]
      |> Repo.preload([:google_auth, :custom_domain])

    search_console_domains =
      if site.google_auth do
        Plausible.Google.Api.fetch_verified_properties(site.google_auth)
      end

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("settings_search_console.html",
      site: site,
      search_console_domains: search_console_domains,
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_email_reports(conn, _params) do
    site = conn.assigns[:site] |> Repo.preload(:custom_domain)

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("settings_email_reports.html",
      site: site,
      weekly_report: Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id),
      monthly_report: Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id),
      spike_notification: Repo.get_by(Plausible.Site.SpikeNotification, site_id: site.id),
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_custom_domain(conn, _params) do
    site =
      conn.assigns[:site]
      |> Repo.preload(:custom_domain)

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("settings_custom_domain.html",
      site: site,
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def settings_danger_zone(conn, _params) do
    site = conn.assigns[:site] |> Repo.preload(:custom_domain)

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("settings_danger_zone.html",
      site: site,
      layout: {PlausibleWeb.LayoutView, "site_settings.html"}
    )
  end

  def update_google_auth(conn, %{"google_auth" => attrs}) do
    site = conn.assigns[:site] |> Repo.preload(:google_auth)

    Plausible.Site.GoogleAuth.set_property(site.google_auth, attrs)
    |> Repo.update!()

    conn
    |> put_flash(:success, "Google integration saved successfully")
    |> redirect(to: Routes.site_path(conn, :settings_search_console, site.domain))
  end

  def delete_google_auth(conn, _params) do
    site =
      conn.assigns[:site]
      |> Repo.preload(:google_auth)

    Repo.delete!(site.google_auth)

    conn = put_flash(conn, :success, "Google account unlinked from Plausible")

    panel =
      conn.path_info
      |> List.last()
      |> String.split("-")
      |> List.last()

    case panel do
      "search" ->
        redirect(conn, to: Routes.site_path(conn, :settings_search_console, site.domain))

      "import" ->
        redirect(conn, to: Routes.site_path(conn, :settings_general, site.domain))
    end
  end

  def update_settings(conn, %{"site" => site_params}) do
    site = conn.assigns[:site] |> Repo.preload(:custom_domain)
    changeset = Plausible.Site.update_changeset(site, site_params)

    case Repo.update(changeset) do
      {:ok, site} ->
        site_session_key = "authorized_site__" <> site.domain

        conn
        |> put_session(site_session_key, nil)
        |> put_flash(:success, "Your site settings have been saved")
        |> redirect(to: Routes.site_path(conn, :settings_general, site.domain))

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
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/danger-zone")
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
    |> redirect(to: Routes.site_path(conn, :settings_visibility, site.domain))
  end

  def make_private(conn, _params) do
    site =
      conn.assigns[:site]
      |> Plausible.Site.make_private()
      |> Repo.update!()

    conn
    |> put_flash(:success, "Stats for #{site.domain} are now private.")
    |> redirect(to: Routes.site_path(conn, :settings_visibility, site.domain))
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
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/email-reports")
  end

  def disable_weekly_report(conn, _params) do
    site = conn.assigns[:site]
    Repo.delete_all(from wr in Plausible.Site.WeeklyReport, where: wr.site_id == ^site.id)

    conn
    |> put_flash(:success, "You will not receive weekly email reports going forward")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/email-reports")
  end

  def add_weekly_report_recipient(conn, %{"recipient" => recipient}) do
    site = conn.assigns[:site]

    Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
    |> Plausible.Site.WeeklyReport.add_recipient(recipient)
    |> Repo.update!()

    conn
    |> put_flash(:success, "Added #{recipient} as a recipient for the weekly report")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/email-reports")
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
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/email-reports")
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
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/email-reports")
  end

  def disable_monthly_report(conn, _params) do
    site = conn.assigns[:site]
    Repo.delete_all(from mr in Plausible.Site.MonthlyReport, where: mr.site_id == ^site.id)

    conn
    |> put_flash(:success, "You will not receive monthly email reports going forward")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/email-reports")
  end

  def add_monthly_report_recipient(conn, %{"recipient" => recipient}) do
    site = conn.assigns[:site]

    Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
    |> Plausible.Site.MonthlyReport.add_recipient(recipient)
    |> Repo.update!()

    conn
    |> put_flash(:success, "Added #{recipient} as a recipient for the monthly report")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/email-reports")
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
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/email-reports")
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
        |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/email-reports")

      {:error, _} ->
        conn
        |> put_flash(:error, "Unable to create a spike notification")
        |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/email-reports")
    end
  end

  def disable_spike_notification(conn, _params) do
    site = conn.assigns[:site]
    Repo.delete_all(from mr in Plausible.Site.SpikeNotification, where: mr.site_id == ^site.id)

    conn
    |> put_flash(:success, "Spike notification disabled")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/email-reports")
  end

  def update_spike_notification(conn, %{"spike_notification" => params}) do
    site = conn.assigns[:site]
    notification = Repo.get_by(Plausible.Site.SpikeNotification, site_id: site.id)

    Plausible.Site.SpikeNotification.changeset(notification, params)
    |> Repo.update!()

    conn
    |> put_flash(:success, "Notification settings updated")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/email-reports")
  end

  def add_spike_notification_recipient(conn, %{"recipient" => recipient}) do
    site = conn.assigns[:site]

    Repo.get_by(Plausible.Site.SpikeNotification, site_id: site.id)
    |> Plausible.Site.SpikeNotification.add_recipient(recipient)
    |> Repo.update!()

    conn
    |> put_flash(:success, "Added #{recipient} as a recipient for the traffic spike notification")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/email-reports")
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
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/email-reports")
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
        redirect(conn, to: "/#{URI.encode_www_form(site.domain)}/settings/visibility")

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
        redirect(conn, to: "/#{URI.encode_www_form(site.domain)}/settings/visibility")

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
           from l in Plausible.Site.SharedLink,
             where: l.slug == ^slug,
             where: l.site_id == ^site_id
         ) do
      {1, _} ->
        conn
        |> put_flash(:success, "Shared Link deleted")
        |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/visibility")

      {0, _} ->
        conn
        |> put_flash(:error, "Could not find Shared Link")
        |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/visibility")
    end
  end

  def delete_custom_domain(conn, %{"id" => domain_id}) do
    site = conn.assigns[:site]
    site_id = site.id

    case Repo.delete_all(
           from d in Plausible.Site.CustomDomain,
             where: d.site_id == ^site_id,
             where: d.id == ^domain_id
         ) do
      {1, _} ->
        conn
        |> put_flash(:success, "Custom domain deleted successfully")
        |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/general")

      {0, _} ->
        conn
        |> put_flash(:error, "Failed to delete custom domain")
        |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings/general")
    end
  end

  def import_from_google_user_metric_notice(conn, %{
        "view_id" => view_id,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at
      }) do
    site = conn.assigns[:site]

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("import_from_google_user_metric_form.html",
      site: site,
      view_id: view_id,
      access_token: access_token,
      refresh_token: refresh_token,
      expires_at: expires_at,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def import_from_google_view_id_form(conn, %{
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at
      }) do
    case Plausible.Google.Api.list_views(access_token) do
      {:ok, view_ids} ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("import_from_google_view_id_form.html",
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: expires_at,
          site: conn.assigns.site,
          view_ids: view_ids,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      {:error, :authentication_failed} ->
        conn
        |> put_flash(
          :error,
          "We were unable to authenticate your Google Analytics account. Please check that you have granted us permission to 'See and download your Google Analytics data' and try again."
        )
        |> redirect(to: Routes.site_path(conn, :settings_general, conn.assigns.site.domain))

      {:error, _any} ->
        conn
        |> put_flash(
          :error,
          "We were unable to list your Google Analytics properties. If the problem persists, please contact support for assistance."
        )
        |> redirect(to: Routes.site_path(conn, :settings_general, conn.assigns.site.domain))
    end
  end

  # see https://stackoverflow.com/a/57416769
  @google_analytics_new_user_metric_date ~D[2016-08-24]
  def import_from_google_view_id(conn, %{
        "view_id" => view_id,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at
      }) do
    site = conn.assigns[:site]
    start_date = Plausible.Google.HTTP.get_analytics_start_date(view_id, access_token)

    case start_date do
      {:ok, nil} ->
        site = conn.assigns[:site]
        {:ok, view_ids} = Plausible.Google.Api.list_views(access_token)

        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("import_from_google_view_id_form.html",
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: expires_at,
          site: site,
          view_ids: view_ids,
          selected_view_id_error: "No data found. Nothing to import",
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      {:ok, date} ->
        if Timex.before?(date, @google_analytics_new_user_metric_date) do
          redirect(conn,
            to:
              Routes.site_path(conn, :import_from_google_user_metric_notice, site.domain,
                view_id: view_id,
                access_token: access_token,
                refresh_token: refresh_token,
                expires_at: expires_at
              )
          )
        else
          redirect(conn,
            to:
              Routes.site_path(conn, :import_from_google_confirm, site.domain,
                view_id: view_id,
                access_token: access_token,
                refresh_token: refresh_token,
                expires_at: expires_at
              )
          )
        end
    end
  end

  def import_from_google_confirm(conn, %{
        "view_id" => view_id,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at
      }) do
    site = conn.assigns[:site]

    start_date = Plausible.Google.HTTP.get_analytics_start_date(view_id, access_token)
    end_date = Plausible.Sites.stats_start_date(site) || Timex.today(site.timezone)

    {:ok, {view_name, view_id}} = Plausible.Google.Api.get_view(access_token, view_id)

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("import_from_google_confirm.html",
      access_token: access_token,
      refresh_token: refresh_token,
      expires_at: expires_at,
      site: site,
      selected_view_id: view_id,
      selected_view_id_name: view_name,
      start_date: start_date,
      end_date: end_date,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def import_from_google(conn, %{
        "view_id" => view_id,
        "start_date" => start_date,
        "end_date" => end_date,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at
      }) do
    site = conn.assigns[:site]

    job =
      Plausible.Workers.ImportGoogleAnalytics.new(%{
        "site_id" => site.id,
        "view_id" => view_id,
        "start_date" => start_date,
        "end_date" => end_date,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "token_expires_at" => expires_at
      })

    Ecto.Multi.new()
    |> Ecto.Multi.update(
      :update_site,
      Plausible.Site.start_import(site, start_date, end_date, "Google Analytics")
    )
    |> Oban.insert(:oban_job, job)
    |> Repo.transaction()

    conn
    |> put_flash(:success, "Import scheduled. An email will be sent when it completes.")
    |> redirect(to: Routes.site_path(conn, :settings_general, site.domain))
  end

  def forget_imported(conn, _params) do
    site = conn.assigns[:site]

    cond do
      site.imported_data ->
        Oban.cancel_all_jobs(
          from j in Oban.Job,
            where:
              j.queue == "google_analytics_imports" and
                fragment("(? ->> 'site_id')::int", j.args) == ^site.id
        )

        Plausible.Imported.forget(site)

        site
        |> Plausible.Site.remove_imported_data()
        |> Repo.update!()

        conn
        |> put_flash(:success, "Imported data has been cleared")
        |> redirect(to: Routes.site_path(conn, :settings_general, site.domain))

      true ->
        conn
        |> put_flash(:error, "No data has been imported")
        |> redirect(to: Routes.site_path(conn, :settings_general, site.domain))
    end
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
          to: Routes.site_path(conn, :add_snippet_after_domain_change, updated_site.domain)
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
    site = conn.assigns[:site] |> Repo.preload(:custom_domain)

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
