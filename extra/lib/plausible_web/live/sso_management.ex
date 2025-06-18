defmodule PlausibleWeb.Live.SSOManagement do
  @moduledoc """
  Live view for SSO setup and management.
  """
  use PlausibleWeb, :live_view

  alias Plausible.Auth.SSO
  alias Plausible.Teams

  alias PlausibleWeb.Router.Helpers, as: Routes
  use Plausible.Auth.SSO.Domain.Status

  @refresh_integration_interval :timer.seconds(5)

  def mount(_params, _session, socket) do
    socket = load_integration(socket, socket.assigns.current_team)

    Process.send_after(self(), :refresh_integration, @refresh_integration_interval)

    {:ok, route_mode(socket)}
  end

  def render(assigns) do
    ~H"""
    <.flash_messages flash={@flash} />

    <.tile :if={@mode != :manage} docs="sso">
      <:title>
        <a id="sso-config">Single Sign-On</a>
      </:title>
      <:subtitle>
        Configure and manage Single Sign-On for your team
      </:subtitle>

      <.init_view :if={@mode == :init} current_team={@current_team} />

      <.init_setup_view
        :if={@mode == :init_setup}
        integration={@integration}
        current_team={@current_team}
      />

      <.idp_form_view
        :if={@mode == :idp_form}
        integration={@integration}
        config_changeset={@config_changeset}
      />

      <.domain_setup_view
        :if={@mode == :domain_setup}
        integration={@integration}
        domain_changeset={@domain_changeset}
      />

      <.domain_verify_view :if={@mode == :domain_verify} domain={@domain} />
    </.tile>

    <.manage_view
      :if={@mode == :manage}
      integration={@integration}
      current_team={@current_team}
      can_toggle_force_sso?={@can_toggle_force_sso?}
      force_sso_warning={@force_sso_warning}
      policy_changeset={@policy_changeset}
      role_options={@role_options}
      domain_delete_checks={@domain_delete_checks}
    />
    """
  end

  def init_view(assigns) do
    ~H"""
    <form id="sso-init" for={} phx-submit="init-sso">
      <p class="text-sm">Click below to start setting up Single Sign-On for your team.</p>

      <.button type="submit">Start Configuring SSO</.button>
    </form>
    """
  end

  def init_setup_view(assigns) do
    ~H"""
    <div class="flex-col space-y-6">
      <p class="text-sm">
        Use the following parameters when configuring your Identity Provider of choice:
      </p>

      <.form id="sso-sp-config" for={} class="flex-col space-y-4">
        <.input_with_clipboard
          id="sp-entity-id"
          name="sp-entity-id"
          label="Entity ID"
          value={SSO.SAMLConfig.entity_id(@integration)}
        />

        <.input_with_clipboard
          id="sp-acs-url"
          name="sp-acs-url"
          label="ACS URL"
          value={saml_acs_url(@integration)}
        />
      </.form>

      <div class="flex-col space-y-3">
        <p class="text-sm">Following attribute mappings must be setup at Identity Provider:</p>

        <ul role="list" class="list-disc leading-6 text-sm ml-8">
          <li :for={param <- ["email", "first_name", "last_name"]}>
            <code>{param}</code>
          </li>
        </ul>
      </div>

      <form id="sso-idp-form" for={} phx-submit="show-idp-form">
        <p class="text-sm">Click below to start setting up Single Sign-On for your team.</p>

        <.button type="submit">Start Configuring</.button>
      </form>
    </div>
    """
  end

  def idp_form_view(assigns) do
    ~H"""
    <div class="flex-col space-y-6">
      <p class="text-sm">
        Enter configuration details of Identity Provider after configuring it:
      </p>

      <.form
        :let={f}
        id="sso-idp-config"
        for={@config_changeset}
        class="flex-col space-y-4"
        phx-submit="update-integration"
      >
        <.input field={f[:idp_signin_url]} label="Sign-in URL" placeholder="<URL>" />

        <.input field={f[:idp_entity_id]} label="Entity ID" placeholder="<Entity ID>" />

        <.input field={f[:idp_cert_pem]} type="textarea" label="Certificate in PEM format" />

        <.button type="submit">Save</.button>
      </.form>
    </div>
    """
  end

  def domain_setup_view(assigns) do
    ~H"""
    <div class="flex-col space-y-6">
      <p class="text-sm">
        In order for Single Sign-On to work, you have to allow at least one email address domain:
      </p>

      <.form
        :let={f}
        id="sso-add-domain"
        for={@domain_changeset}
        class="flex-col space-y-4"
        phx-submit="add-domain"
      >
        <.input field={f[:domain]} label="Domain" placeholder="example.com" />

        <.button type="submit">Add Domain</.button>
      </.form>
    </div>
    """
  end

  def domain_verify_view(assigns) do
    ~H"""
    <div class="flex-col space-y-6">
      <p class="text-sm">Verifying domain {@domain.domain}</p>

      <p class="text-sm">You can verify ownership of the domain using one of 3 methods:</p>

      <ul class="list-disc ml-4 space-y-6">
        <li>
          <.input_with_clipboard
            name="verification-dns-txt"
            label={"Add a TXT record to #{@domain.domain} domain with the following value"}
            id="verification-dns-txt"
            value={"plausible-sso-verification=#{@domain.identifier}"}
          />
        </li>
        <li>
          <.input_with_clipboard
            name="verification-url"
            label={"Publish a file or route at https://#{@domain.domain}/plausible-sso-verification rendering the following contents"}
            id="verification-url"
            value={@domain.identifier}
          />
        </li>
        <li>
          <.input_with_clipboard
            name="verification-meta-tag"
            label={"Add a following META tag to the web page at https://#{@domain.domain}"}
            id="verification-meta-tag"
            value={~s|<meta name="plausible-sso-verification" content="#{@domain.identifier}">|}
          />
        </li>
      </ul>

      <.notice>
        We'll keep checking your domain ownership. Once any of the above verification methods succeeds, we'll send you an e-mail. Thank you for your patience.
      </.notice>

      <form id="verify-domain-submit" for={} phx-submit="verify-domain-submit">
        <.input type="hidden" name="domain" value={@domain.domain} />
        <.button
          :if={@domain.status in [Status.in_progress(), Status.unverified(), Status.verified()]}
          type="submit"
        >
          Run verification now
        </.button>

        <.button :if={@domain.status == Status.pending()} type="submit">Continue</.button>
      </form>
    </div>
    """
  end

  def manage_view(assigns) do
    ~H"""
    <.tile docs="sso">
      <:title>
        <a id="sso-manage-config">Single Sign-On</a>
      </:title>
      <:subtitle>
        Configure and manage Single Sign-On for your team
      </:subtitle>

      <div class="flex-col space-y-6">
        <p class="text-sm">
          Use the following parameters when configuring your Identity Provider of choice:
        </p>

        <form id="sso-sp-config" for={} class="flex-col space-y-4">
          <.input_with_clipboard
            id="sp-entity-id"
            name="sp-entity-id"
            label="Entity ID"
            value={SSO.SAMLConfig.entity_id(@integration)}
          />

          <.input_with_clipboard
            id="sp-acs-url"
            name="sp-acs-url"
            label="ACS URL"
            value={saml_acs_url(@integration)}
          />
        </form>

        <div class="flex-col space-y-3">
          <p class="text-sm">Following attribute mappings must be setup at Identity Provider:</p>

          <ul role="list" class="list-disc leading-6 text-sm ml-8">
            <li :for={param <- ["email", "first_name", "last_name"]}>
              <code>{param}</code>
            </li>
          </ul>
        </div>

        <div class="flex-col space-y-3">
          <p class="text-sm">
            Current Identity Provider configuration:
          </p>

          <.form :let={f} id="sso-idp-config" for={} class="flex-col space-y-4">
            <.input
              field={f[:idp_signin_url]}
              value={@integration.config.idp_signin_url}
              label="Sign-in URL"
              readonly={true}
            />

            <.input
              field={f[:idp_entity_id]}
              value={@integration.config.idp_entity_id}
              label="Entity ID"
              readonly={true}
            />

            <.input
              field={f[:idp_cert_pem]}
              type="textarea"
              label="Certificate in PEM format"
              value={@integration.config.idp_cert_pem}
              readonly={true}
            />
          </.form>

          <form id="show-idp-form" for={} phx-submit="show-idp-form">
            <.button type="submit">Edit</.button>
          </form>
        </div>
      </div>
    </.tile>

    <.tile docs="sso">
      <:title>
        <a id="sso-domains-config">SSO Domains</a>
      </:title>
      <:subtitle>
        Email domains accepted from Identity Provider
      </:subtitle>
      <div class="flex-col space-y-3">
        <.table rows={@integration.sso_domains}>
          <:thead>
            <.th>Domain</.th>
            <.th hide_on_mobile>Added at</.th>
            <.th>Status</.th>
            <.th invisible>Actions</.th>
          </:thead>
          <:tbody :let={domain}>
            <.td>{domain.domain}</.td>
            <.td hide_on_mobile>
              {Calendar.strftime(domain.inserted_at, "%b %-d, %Y at %H:%m UTC")}
            </.td>
            <.td :if={domain.status != Status.in_progress()}>{domain.status}</.td>
            <.td :if={domain.status == Status.in_progress()}>
              <div class="flex items-center gap-x-2">
                <.spinner class="w-4 h-4" />
                <.styled_link
                  id={"cancel-verify-domain-#{domain.identifier}"}
                  phx-click="cancel-verify-domain"
                  phx-value-identifier={domain.identifier}
                >
                  Cancel
                </.styled_link>
              </div>
            </.td>
            <.td actions>
              <.styled_link
                :if={domain.status != Status.in_progress()}
                id={"verify-domain-#{domain.identifier}"}
                phx-click="verify-domain"
                phx-value-identifier={domain.identifier}
              >
                Verify
              </.styled_link>

              <.delete_button
                :if={is_nil(@domain_delete_checks[domain.identifier])}
                id={"remove-domain-#{domain.identifier}"}
                phx-click="remove-domain"
                phx-value-identifier={domain.identifier}
                class="text-sm text-red-600"
                data-confirm={"Are you sure you want to remove domain '#{domain.domain}'?"}
              />

              <.delete_button
                :if={@domain_delete_checks[domain.identifier]}
                id={"disabled-remove-domain-#{domain.identifier}"}
                class="text-sm text-red-600"
                data-confirm={"You cannot delete this domain. #{@domain_delete_checks[domain.identifier]}"}
              />
            </.td>
          </:tbody>
        </.table>

        <form id="show-domain-setup" for={} phx-submit="show-domain-setup">
          <.button type="submit">Add Domain</.button>
        </form>
      </div>
    </.tile>

    <.tile docs="sso">
      <:title>
        <a id="sso-policy-config">SSO Policy</a>
      </:title>
      <:subtitle>
        Adjust your SSO policy configuration
      </:subtitle>
      <div
        x-data={Jason.encode!(%{active: @current_team.policy.force_sso == :all_but_owners})}
        class="flex-col space-y-3"
      >
        <p class="text-sm">Enforce Single Sign-On for the whole team, except Owners:</p>

        <.tooltip enabled?={not @can_toggle_force_sso?}>
          <:tooltip_content>
            <div class="text-xs">
              To get access to this feature, {@force_sso_warning}.
            </div>
          </:tooltip_content>
          <div class="flex itemx-center mb-3">
            <PlausibleWeb.Components.Generic.toggle_switch
              id="enable-force-sso"
              id_suffix="toggle"
              js_active_var="active"
              disabled={not @can_toggle_force_sso?}
              phx-click="toggle-force-sso"
            />
            <span class={[
              "ml-3 text-sm font-medium",
              if(@can_toggle_force_sso?,
                do: "text-gray-900 dark:text-gray-100",
                else: "text-gray-500 dark:text-gray-400"
              )
            ]}>
              Force Single Sign-On
            </span>
          </div>
        </.tooltip>
      </div>

      <div class="flex-col space-y-3">
        <.form
          :let={f}
          id="sso-policy"
          for={@policy_changeset}
          class="flex-col space-y-4"
          phx-submit="update-policy"
        >
          <.input
            field={f[:sso_default_role]}
            label="Default role"
            type="select"
            options={@role_options}
          />

          <.input
            field={f[:sso_session_timeout_minutes]}
            label="Session timeout (minutes)"
            type="number"
          />

          <.button type="submit">Update</.button>
        </.form>
      </div>
    </.tile>
    """
  end

  def handle_event("init-sso", _params, socket) do
    team = socket.assigns.current_team
    integration = SSO.initiate_saml_integration(team)

    socket =
      socket
      |> assign(:integration, integration)
      |> load_integration(team)
      |> route_mode()

    {:noreply, socket}
  end

  def handle_event("show-idp-form", _params, socket) do
    {:noreply, route_mode(socket, :idp_form)}
  end

  def handle_event("update-integration", params, socket) do
    socket =
      case SSO.update_integration(socket.assigns.integration, params["saml_config"] || %{}) do
        {:ok, integration} ->
          socket
          |> assign(:integration, integration)
          |> load_integration(socket.assigns.current_team)
          |> route_mode()

        {:error, changeset} ->
          assign(socket, :config_changeset, changeset)
      end

    {:noreply, socket}
  end

  def handle_event("add-domain", params, socket) do
    integration = socket.assigns.integration

    socket =
      case SSO.Domains.add(integration, params["domain"]["domain"] || "") do
        {:ok, sso_domain} ->
          socket
          |> load_integration(socket.assigns.current_team)
          |> assign(:domain, sso_domain)
          |> route_mode(:domain_verify)

        {:error, changeset} ->
          socket
          |> assign(:domain_changeset, changeset)
      end

    {:noreply, socket}
  end

  def handle_event("verify-domain-submit", %{"domain" => domain}, socket) do
    SSO.Domains.start_verification(domain)

    {:noreply, route_mode(load_integration(socket, socket.assigns.current_team), :manage)}
  end

  def handle_event("show-domain-setup", _params, socket) do
    {:noreply, route_mode(socket, :domain_setup)}
  end

  def handle_event("verify-domain", params, socket) do
    integration = socket.assigns.integration
    domain = Enum.find(integration.sso_domains, &(&1.identifier == params["identifier"]))

    if domain do
      socket =
        socket
        |> load_integration(socket.assigns.current_team)
        |> assign(:domain, domain)
        |> route_mode(:domain_verify)

      {:noreply, socket}
    else
      {:noreply, route_mode(socket, :manage)}
    end
  end

  def handle_event("cancel-verify-domain", params, socket) do
    integration = socket.assigns.integration
    domain = Enum.find(integration.sso_domains, &(&1.identifier == params["identifier"]))

    socket =
      if domain do
        :ok = SSO.Domains.cancel_verification(domain.domain)
        load_integration(socket, socket.assigns.current_team)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("remove-domain", params, socket) do
    integration = socket.assigns.integration
    domain = Enum.find(integration.sso_domains, &(&1.identifier == params["identifier"]))

    if domain do
      socket =
        case SSO.Domains.remove(domain) do
          :ok ->
            socket
            |> load_integration(socket.assigns.current_team)
            |> route_mode()

          {:error, :force_sso_enabled} ->
            socket

          {:error, :sso_users_present} ->
            socket
        end

      {:noreply, socket}
    else
      {:noreply, route_mode(socket, :manage)}
    end
  end

  def handle_event("toggle-force-sso", _params, socket) do
    team = socket.assigns.current_team
    new_toggle = if team.policy.force_sso == :none, do: :all_but_owners, else: :none

    case SSO.set_force_sso(socket.assigns.current_team, new_toggle) do
      {:ok, team} ->
        socket =
          socket
          |> assign(:current_team, team)

        {:noreply, socket}

      {:error, _} ->
        {:noreply, route_mode(socket, :manage)}
    end
  end

  def handle_event("update-policy", params, socket) do
    team = socket.assigns.current_team
    params = params["policy"]

    attrs = [
      sso_default_role: params["sso_default_role"],
      sso_session_timeout_minutes: params["sso_session_timeout_minutes"]
    ]

    socket =
      case SSO.update_policy(team, attrs) do
        {:ok, team} ->
          policy_changeset = Teams.Policy.update_changeset(team.policy, %{})

          socket
          |> assign(:current_team, team)
          |> assign(:policy_changeset, policy_changeset)

        {:error, changeset} ->
          socket
          |> assign(:policy_changeset, changeset)
      end

    {:noreply, socket}
  end

  def handle_info(:refresh_integration, socket) do
    {:noreply, load_integration(socket, socket.assigns.current_team)}
  end

  defp load_integration(socket, team) do
    integration =
      case SSO.get_integration_for(team) do
        {:ok, integration} -> integration
        {:error, :not_found} -> nil
      end

    assign(socket, :integration, integration)
  end

  defp route_mode(socket, force_mode \\ nil) do
    integration = socket.assigns.integration

    mode =
      cond do
        force_mode ->
          force_mode

        is_nil(integration) ->
          :init

        not SSO.Integration.configured?(integration) ->
          :init_setup

        integration.sso_domains == [] ->
          :domain_setup

        true ->
          :manage
      end

    socket
    |> assign(:mode, mode)
    |> load(mode)
  end

  defp load(socket, :idp_form) do
    assign(
      socket,
      :config_changeset,
      SSO.SAMLConfig.changeset(socket.assigns.integration.config, %{})
    )
  end

  defp load(socket, :domain_setup) do
    assign(socket, :domain_changeset, SSO.Domain.create_changeset(socket.assigns.integration, ""))
  end

  defp load(socket, :manage) do
    team = socket.assigns.current_team
    toggle_mode = if team.policy.force_sso == :none, do: :all_but_owners, else: :none

    {can_toggle_force_sso?, toggle_disabled_reason} =
      case SSO.check_force_sso(team, toggle_mode) do
        :ok ->
          {true, nil}

        {:error, :no_integration} ->
          {false, "you must first setup Single Sign-on"}

        {:error, :no_domain} ->
          {false, "you must add a domain"}

        {:error, :no_verified_domain} ->
          {false, "you must verify a domain"}

        {:error, :owner_mfa_disabled} ->
          {false, "all Owners must have MFA enabled"}

        {:error, :no_sso_user} ->
          {false, "at least one SSO user must log in successfully"}
      end

    policy_changeset = Teams.Policy.update_changeset(team.policy, %{})

    role_options =
      Enum.map(Teams.Policy.sso_member_roles(), fn role ->
        {String.capitalize(to_string(role)), role}
      end)
      |> Enum.sort()

    domain_delete_checks =
      Enum.into(socket.assigns.integration.sso_domains, %{}, fn domain ->
        prevent_delete_reason =
          case Plausible.Auth.SSO.Domains.check_can_remove(domain) do
            :ok -> nil
            {:error, :force_sso_enabled} -> "You must disable 'Force SSO' first."
            {:error, :sso_users_present} -> "There are existing SSO accounts on this domain."
          end

        {domain.identifier, prevent_delete_reason}
      end)

    socket
    |> assign(:domain_delete_checks, domain_delete_checks)
    |> assign(:can_toggle_force_sso?, can_toggle_force_sso?)
    |> assign(:force_sso_warning, toggle_disabled_reason)
    |> assign(:policy_changeset, policy_changeset)
    |> assign(:role_options, role_options)
  end

  defp load(socket, _) do
    socket
  end

  defp saml_acs_url(integration) do
    Routes.sso_url(
      PlausibleWeb.Endpoint,
      :saml_consume,
      integration.identifier
    )
  end
end
