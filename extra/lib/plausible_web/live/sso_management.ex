defmodule PlausibleWeb.Live.SSOManagement do
  @moduledoc """
  Live view for SSO setup and management.
  """
  use PlausibleWeb, :live_view

  alias Plausible.Auth.SSO
  alias Plausible.Repo
  alias Plausible.Teams

  alias PlausibleWeb.Router.Helpers, as: Routes

  @fake_verify_interval :timer.seconds(10)

  def mount(_params, _session, socket) do
    socket = load_integration(socket, socket.assigns.current_team)

    Process.send_after(self(), :fake_domain_verify, @fake_verify_interval)

    {:ok, route_mode(socket)}
  end

  def render(assigns) do
    ~H"""
    <.flash_messages flash={@flash} />

    <.init_view :if={@mode == :init} current_team={@current_team} />

    <.init_setup_view
      :if={@mode == :init_setup}
      integration={@integration}
      current_team={@current_team}
    />

    <.saml_form_view
      :if={@mode == :saml_form}
      integration={@integration}
      config_changeset={@config_changeset}
    />

    <.domain_setup_view
      :if={@mode == :domain_setup}
      integration={@integration}
      domain_changeset={@domain_changeset}
    />

    <.domain_verify_view :if={@mode == :domain_verify} domain={@domain} />

    <.manage_view
      :if={@mode == :manage}
      integration={@integration}
      current_team={@current_team}
      can_toggle_force_sso?={@can_toggle_force_sso?}
      force_sso_warning={@force_sso_warning}
      policy_changeset={@policy_changeset}
      role_options={@role_options}
    />
    """
  end

  def init_view(assigns) do
    ~H"""
    <form id="sso-init-form" for={} phx-submit="init-sso">
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
          id="sp-enity-id"
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

        <ul role="list" class="space-y-3 leading-6 text-sm">
          <li :for={param <- ["email", "first_name", "last_name"]} class="flex gap-x-3">
            <Heroicons.arrow_right_circle class="h-6 w-5" />
            <pre>{param}</pre>
          </li>
        </ul>
      </div>

      <form id="sso-saml-form" for={} phx-submit="show-saml-form">
        <p class="text-sm">Click below to start setting up Single Sign-On for your team.</p>

        <.button type="submit">Start Configuring</.button>
      </form>
    </div>
    """
  end

  def saml_form_view(assigns) do
    ~H"""
    <div class="flex-col space-y-6">
      <p class="text-sm">
        Enter configuration details of Identity Provider after configuring it:
      </p>

      <.form
        :let={f}
        id="sso-sp-config-form"
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
        In order for Single Sign-On to work, you have allow at least one email address domain:
      </p>

      <.form
        :let={f}
        id="sso-add-domain-form"
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

      <p class="text-sm">You can verify the domain using one of 3 methods:</p>

      <ol>
        <li>
          Add a <pre>TXT</pre> record to {@domain.domain} with a following value: <pre>
            plausible-sso-verification={@domain.identifier}
          </pre>
        </li>
        <li>
          Publish a file or route at https://{@domain.domain}/plausible-sso-verification with the following contents: <pre>
            {@domain.identifier}
          </pre>
        </li>
        <li>
          Add a following META tag to the web page at https://{@domain.identifier}: <pre>
            <meta name="plausible-sso-verification" content="{@domain.identifier}">
          </pre>
        </li>
      </ol>

      <form id="show-manage-form" for={} phx-submit="show-manage">
        <.button type="submit">Continue</.button>
      </form>
    </div>
    """
  end

  def manage_view(assigns) do
    ~H"""
    <div class="flex-col space-y-6">
      <p class="text-sm">
        Use the following parameters when configuring your Identity Provider of choice:
      </p>

      <form id="sso-sp-config" for={} class="flex-col space-y-4">
        <.input_with_clipboard
          id="sp-enity-id"
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

        <ul role="list" class="space-y-3 leading-6 text-sm">
          <li :for={param <- ["email", "first_name", "last_name"]} class="flex gap-x-3">
            <Heroicons.arrow_right_circle class="h-6 w-5" />
            <pre>{param}</pre>
          </li>
        </ul>
      </div>

      <div class="flex-col space-y-3">
        <p class="text-sm">
          Current Identity Provider configuration:
        </p>

        <.form :let={f} id="sso-sp-config-form" for={} class="flex-col space-y-4">
          <.input
            name="idp_signin_url"
            value={@integration.config.idp_signin_url}
            label="Sign-in URL"
            readonly={true}
          />

          <.input
            name="idp_entity_id"
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

        <form id="show-saml-form" for={} phx-submit="show-saml-form">
          <.button type="submit">Edit</.button>
        </form>
      </div>

      <div class="flex-col space-y-3">
        <p class="text-sm">
          Email domains accepted from Identity Provider:
        </p>

        <.table rows={@integration.sso_domains}>
          <:thead>
            <.th>Domain</.th>
            <.th>Added at</.th>
            <.th>Status</.th>
            <.th invisible>Actions</.th>
          </:thead>
          <:tbody :let={domain}>
            <.td>{domain.domain}</.td>
            <.td>{domain.inserted_at}</.td>
            <.td>{domain.status}</.td>
            <.td actions>
              <.styled_link
                id="verify-domain-#{domain.identifier}"
                phx-click="verify-domain"
                phx-value-identifier={domain.identifier}
              >
                Verify
              </.styled_link>

              <.styled_link
                id="remove-domain-#{domain.identifier}"
                phx-click="remove-domain"
                phx-value-identifier={domain.identifier}
              >
                Remove
              </.styled_link>
            </.td>
          </:tbody>
        </.table>

        <form id="show-domain-form" for={} phx-submit="show-domain-form">
          <.button type="submit">Add Domain</.button>
        </form>
      </div>

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
        <p class="text-sm">
          Adjust Single Sign-On policy:
        </p>

        <.form
          :let={f}
          id="sso-policy-form"
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

          <.input field={f[:sso_session_timeout_minutes]} label="Session timeout (minutes)" />

          <.button type="submit">Update</.button>
        </.form>
      </div>
    </div>
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

  def handle_event("show-saml-form", _params, socket) do
    {:noreply, route_mode(socket, :saml_form)}
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
          socket
          |> assign(:config_changeset, changeset)
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

  def handle_event("show-manage", _params, socket) do
    {:noreply, route_mode(socket, :manage)}
  end

  def handle_event("show-domain-form", _params, socket) do
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
          socket
          |> assign(:current_team, team)

        {:error, changeset} ->
          socket
          |> assign(:policy_changeset, changeset)
      end

    {:noreply, socket}
  end

  def handle_info(:fake_domain_verify, socket) do
    integration = socket.assigns.integration

    sso_domains =
      integration.sso_domains
      |> Enum.map(fn domain ->
        if domain.status == :pending do
          SSO.Domains.verify(domain, skip_checks?: true)
        else
          domain
        end
      end)

    integration = %{integration | sso_domains: sso_domains}

    Process.send_after(self(), :fake_domain_verify, @fake_verify_interval)

    {:noreply, assign(socket, :integration, integration)}
  end

  defp load_integration(socket, team) do
    result =
      if integration = socket.assigns[:integration] do
        {:ok, Repo.reload(integration)}
      else
        SSO.get_integration_for(team)
      end

    integration =
      case result do
        {:ok, integration} -> Repo.preload(integration, :sso_domains)
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

  defp load(socket, :saml_form) do
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
    role_options = Teams.Policy.sso_member_roles()

    socket
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
