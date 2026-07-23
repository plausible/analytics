defmodule PlausibleWeb.Live.RegisterForm do
  @moduledoc """
  LiveView for registration form.
  """

  use PlausibleWeb, :live_view

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Teams

  def mount(params, _session, socket) do
    socket =
      socket
      |> assign_new(:invitation, fn ->
        if invitation_id = params["invitation_id"] do
          find_by_id_unified(invitation_id)
        end
      end)
      |> assign_new(:team_identifier, fn %{invitation: invitation} ->
        if invitation do
          invitation.team_identifier
        end
      end)

    if socket.assigns.live_action == :register_from_invitation_form and
         socket.assigns.invitation == nil do
      {:ok,
       assign(socket,
         invitation_expired: true,
         heading: "Invitation no longer valid",
         subtitle:
           "This invitation has expired or was revoked. Ask your team admin to send you a new invitation."
       )}
    else
      changeset =
        if invitation = socket.assigns.invitation do
          Auth.User.settings_changeset(%Auth.User{email: invitation.email})
        else
          Auth.User.settings_changeset(%Auth.User{})
        end

      {heading, subtitle} = heading_and_subtitle(socket.assigns.live_action)

      {:ok,
       assign(socket,
         form: to_form(changeset),
         captcha_error: nil,
         password_strength: Auth.User.password_strength(changeset),
         disable_submit: false,
         trigger_submit: false,
         heading: heading,
         subtitle: subtitle
       )}
    end
  end

  defp heading_and_subtitle(:register_from_invitation_form) do
    {"Create your account", "Accept your invitation to join your team."}
  end

  defp heading_and_subtitle(:register_form) do
    if ce?() do
      {"Create your #{Plausible.product_name()} account",
       "Start tracking privacy-friendly analytics in minutes."}
    else
      {"Start your 30-day free trial", "No credit card required. Cancel anytime."}
    end
  end

  def render(%{invitation_expired: true} = assigns) do
    ~H"""
    <.auth_container class="flex gap-3 justify-center">
      <.button_link href="/register" mt?={false}>
        Start free trial
      </.button_link>
      <.button_link href="/login" theme="secondary" mt?={false}>
        Sign in
      </.button_link>
    </.auth_container>
    """
  end

  def render(assigns) do
    ~H"""
    <.auth_container>
      <.form
        :let={f}
        for={@form}
        id="register-form"
        class="flex flex-col gap-y-6"
        action={Routes.auth_path(@socket, :login)}
        onsubmit={form_submit_event(@invitation)}
        phx-hook="Metrics"
        phx-change="validate"
        phx-submit="register"
        phx-trigger-action={@trigger_submit}
      >
        <input name="user[register_action]" type="hidden" value={@live_action} />
        <input
          :if={@team_identifier}
          name="user[team_identifier]"
          type="hidden"
          value={@team_identifier}
        />

        <%= if @invitation do %>
          <.email_input field={f[:email]} for_invitation={true} />
          <.name_input field={f[:name]} />
        <% else %>
          <.name_input field={f[:name]} />
          <.email_input field={f[:email]} for_invitation={false} />
        <% end %>

        <div class="flex flex-col gap-y-2">
          <label
            for={f[:password].id}
            class="text-sm font-semibold text-gray-800 dark:text-gray-200"
          >
            Password
          </label>
          <div>
            <.password_input_with_strength
              field={f[:password]}
              strength={@password_strength}
              phx-debounce={200}
              mt?={false}
            />
          </div>
          <.password_length_hint minimum={12} field={f[:password]} hide_when_used?={true} />
        </div>

        <%= if PlausibleWeb.Captcha.enabled?() do %>
          <div>
            <div
              phx-update="ignore"
              id="frc-captcha-placeholder"
              class="frc-captcha hidden"
              data-sitekey={PlausibleWeb.Captcha.sitekey()}
              data-start="auto"
            >
            </div>
            <p :if={@captcha_error} class="text-xs text-red-500 mt-2">
              {@captcha_error}
            </p>
            <p class="text-xs text-gray-500 dark:text-gray-400">
              This site is protected by
              <.styled_link href="https://friendlycaptcha.com" new_tab={true}>
                Friendly Captcha
              </.styled_link>
            </p>
            <script
              phx-update="ignore"
              id="frc-captcha-script"
              type="module"
              src="https://cdn.jsdelivr.net/npm/@friendlycaptcha/sdk@1/site.min.js"
              async
              defer
            >
            </script>
            <script
              phx-update="ignore"
              id="frc-captcha-script-compat"
              nomodule
              src="https://cdn.jsdelivr.net/npm/@friendlycaptcha/sdk@1/site.compat.min.js"
              async
              defer
            >
            </script>
            <script phx-update="ignore" id="frc-captcha-reveal">
              (function () {
                var SHOW_AFTER_LONG_WAIT_MS = 5000;
                var el = document.getElementById("frc-captcha-placeholder");
                if (!el) return;
                function show() { el.classList.remove("hidden"); }
                var timeout;
                // Friendly Captcha carries the event payload on `e.detail` (not `e`).
                el.addEventListener("frc:widget.statechange", function (e) {
                  var d = e.detail || {};
                  // Interactive mode means the user must click to solve: reveal the widget.
                  if (d.mode === "interactive") { show(); }
                  // Reveal if solving takes unusually long, then stop waiting once done.
                  if (d.state === "requesting") {
                    clearTimeout(timeout);
                    timeout = setTimeout(show, SHOW_AFTER_LONG_WAIT_MS);
                  } else if (d.state === "completed") {
                    clearTimeout(timeout);
                  }
                  // Reveal on error or expiry so the user can recover.
                  if (d.state === "error" || d.state === "expired") { show(); }
                  // Enable the submit button only once we hold a valid solution.
                  window.dispatchEvent(new Event(
                    d.state === "completed" ? "frc-captcha-ready" : "frc-captcha-reset"
                  ));
                });
              })();
            </script>
          </div>
        <% end %>

        <div class="flex flex-col gap-y-4">
          <% submit_text =
            if ce?() or @invitation do
              "Create my account"
            else
              "Start my free trial"
            end %>
          <.button
            id="register"
            type="submit"
            class="w-full"
            mt?={false}
            data-disable-submit={to_string(@disable_submit)}
            x-data={"{ captchaReady: #{not PlausibleWeb.Captcha.enabled?()} }"}
            x-on:frc-captcha-ready.window="captchaReady = true"
            x-on:frc-captcha-reset.window="captchaReady = false"
            x-bind:disabled="!captchaReady || $el.dataset.disableSubmit === 'true'"
          >
            {submit_text}
          </.button>

          <p class="text-sm text-center text-gray-500 dark:text-gray-400">
            Already have an account?
            <.styled_link href="/login">
              Sign in
            </.styled_link>
          </p>
        </div>
      </.form>
    </.auth_container>
    """
  end

  on_ee do
    defp form_submit_event(invitation) do
      "window.plausible('Signup#{if invitation, do: " via invitation"}')"
    end
  else
    defp form_submit_event(_), do: ""
  end

  defp name_input(assigns) do
    ~H"""
    <div class="flex flex-col gap-y-2">
      <label for={@field.id} class="text-sm font-semibold text-gray-800 dark:text-gray-200">
        Full name
      </label>
      <div>
        <.input
          field={@field}
          placeholder="Jane Doe"
          phx-debounce={200}
          mt?={false}
          autofocus="autofocus"
        />
      </div>
    </div>
    """
  end

  defp email_input(assigns) do
    email_readonly =
      if assigns[:for_invitation] do
        [readonly: "readonly"]
      else
        []
      end

    assigns = assign(assigns, :email_readonly, email_readonly)

    ~H"""
    <div class="flex flex-col gap-y-2">
      <label for={@field.id} class="text-sm font-semibold text-gray-800 dark:text-gray-200">
        Email
      </label>
      <div>
        <.input
          type="email"
          field={@field}
          placeholder="example@email.com"
          phx-debounce={200}
          mt?={false}
          {@email_readonly}
        />
      </div>
    </div>
    """
  end

  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      params
      |> Auth.User.new()
      |> Map.put(:action, :validate)

    password_strength = Auth.User.password_strength(changeset)

    {:noreply,
     assign(socket,
       form: to_form(changeset),
       password_strength: password_strength,
       captcha_error: nil
     )}
  end

  def handle_event(
        "register",
        %{"user" => _} = params,
        %{assigns: %{invitation: %{} = invitation}} = socket
      ) do
    if not PlausibleWeb.Captcha.enabled?() or
         PlausibleWeb.Captcha.verify(params["frc-captcha-response"]) do
      user =
        params["user"]
        |> Map.put("email", invitation.email)
        |> Auth.User.new()

      with_team? = invitation.type == :site_transfer

      add_user(socket, user, with_team?: with_team?)
    else
      {:noreply, assign(socket, :captcha_error, "Please complete the captcha to register")}
    end
  end

  def handle_event("register", %{"user" => _} = params, socket) do
    if not PlausibleWeb.Captcha.enabled?() or
         PlausibleWeb.Captcha.verify(params["frc-captcha-response"]) do
      user = Auth.User.new(params["user"])

      add_user(socket, user)
    else
      {:noreply, assign(socket, :captcha_error, "Please complete the captcha to register")}
    end
  end

  defp add_user(socket, user, opts \\ []) do
    result =
      Repo.transaction(fn ->
        do_add_user(user, opts)
      end)

    case result do
      {:ok, _user} ->
        socket = assign(socket, disable_submit: true)

        {:noreply, assign(socket, trigger_submit: true)}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(Map.put(changeset, :action, :validate))
         )}
    end
  end

  defp do_add_user(user, opts) do
    case Repo.insert(user) do
      {:ok, user} ->
        if opts[:with_team?] do
          {:ok, _} = Plausible.Teams.get_or_create(user)
        end

        user

      {:error, reason} ->
        Repo.rollback(reason)
    end
  end

  defp find_by_id_unified(invitation_or_transfer_id) do
    result =
      with {:error, :invitation_not_found} <-
             find_team_invitation_by_id_unified(invitation_or_transfer_id),
           {:error, :invitation_not_found} <-
             find_invitation_by_id_unified(invitation_or_transfer_id) do
        find_transfer_by_id_unified(invitation_or_transfer_id)
      end

    case result do
      {:error, :invitation_not_found} -> nil
      {:ok, unified} -> unified
    end
  end

  defp find_team_invitation_by_id_unified(id) do
    invitation =
      Teams.Invitation
      |> Repo.get_by(invitation_id: id)
      |> Repo.preload(:team)

    case invitation do
      nil ->
        {:error, :invitation_not_found}

      team_invitation ->
        {:ok,
         %{
           type: :team_invitation,
           email: team_invitation.email,
           team_identifier: team_invitation.team.identifier
         }}
    end
  end

  defp find_invitation_by_id_unified(id) do
    invitation =
      Teams.GuestInvitation
      |> Repo.get_by(invitation_id: id)
      |> Repo.preload(:team_invitation)

    case invitation do
      nil ->
        {:error, :invitation_not_found}

      guest_invitation ->
        {:ok,
         %{
           type: :guest_invitation,
           email: guest_invitation.team_invitation.email,
           team_identifier: nil
         }}
    end
  end

  defp find_transfer_by_id_unified(id) do
    transfer =
      Teams.SiteTransfer
      |> Repo.get_by(transfer_id: id)

    case transfer do
      nil ->
        {:error, :invitation_not_found}

      transfer ->
        {:ok,
         %{
           type: :site_transfer,
           email: transfer.email,
           team_identifier: nil
         }}
    end
  end
end
