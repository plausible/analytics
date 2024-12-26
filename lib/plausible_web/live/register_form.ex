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
      assign_new(socket, :invitation, fn ->
        if invitation_id = params["invitation_id"] do
          find_by_id_unified(invitation_id)
        end
      end)

    if socket.assigns.live_action == :register_from_invitation_form and
         socket.assigns.invitation == nil do
      {:ok, assign(socket, invitation_expired: true)}
    else
      changeset =
        if invitation = socket.assigns.invitation do
          Auth.User.settings_changeset(%Auth.User{email: invitation.email})
        else
          Auth.User.settings_changeset(%Auth.User{})
        end

      {:ok,
       assign(socket,
         form: to_form(changeset),
         captcha_error: nil,
         password_strength: Auth.User.password_strength(changeset),
         disable_submit: false,
         trigger_submit: false
       )}
    end
  end

  def render(%{invitation_expired: true} = assigns) do
    ~H"""
    <div class="mx-auto mt-6 text-center dark:text-gray-300">
      <h1 class="text-3xl font-black"><%= Plausible.product_name() %></h1>
      <div class="text-xl font-medium">Lightweight and privacy-friendly web analytics</div>
    </div>

    <div class="w-full max-w-md mx-auto bg-white dark:bg-gray-800 shadow-md rounded px-8 py-6 mb-4 mt-8">
      <h2 class="text-xl font-black dark:text-gray-100">Invitation expired</h2>

      <p class="mt-4">
        Your invitation has expired or been revoked. Please request fresh one or you can
        <.styled_link href={Routes.auth_path(@socket, :register_form)}>sign up</.styled_link>
        for a 30-day unlimited free trial without an invitation.
      </p>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto text-center dark:text-gray-300">
      <h1 class="text-3xl font-black">
        <%= if ce?() or @live_action == :register_from_invitation_form do %>
          Register your <%= Plausible.product_name() %> account
        <% else %>
          Register your 30-day free trial
        <% end %>
      </h1>
      <div class="text-xl font-medium mt-2">
        Set up privacy-friendly analytics with just a few clicks
      </div>
    </div>

    <PlausibleWeb.Components.FlowProgress.render
      :if={@live_action == :register_form}
      flow={PlausibleWeb.Flows.register()}
      current_step="Register"
    />
    <PlausibleWeb.Components.FlowProgress.render
      :if={@live_action == :register_from_invitation_form}
      flow={PlausibleWeb.Flows.invitation()}
      current_step="Register"
    />

    <.focus_box>
      <:title>
        Enter your details
      </:title>

      <.form
        :let={f}
        for={@form}
        id="register-form"
        action={Routes.auth_path(@socket, :login)}
        phx-hook="Metrics"
        phx-change="validate"
        phx-submit="register"
        phx-trigger-action={@trigger_submit}
      >
        <input name="user[register_action]" type="hidden" value={@live_action} />

        <%= if @invitation do %>
          <.email_input field={f[:email]} for_invitation={true} />
          <.name_input field={f[:name]} />
        <% else %>
          <.name_input field={f[:name]} />
          <.email_input field={f[:email]} for_invitation={false} />
        <% end %>

        <div class="my-4">
          <div class="flex justify-between">
            <label for={f[:password].name} class="block font-medium text-gray-700 dark:text-gray-300">
              Password
            </label>
            <.password_length_hint minimum={12} field={f[:password]} />
          </div>
          <div class="mt-1">
            <.password_input_with_strength
              field={f[:password]}
              strength={@password_strength}
              phx-debounce={200}
              class="dark:bg-gray-900 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full border-gray-300 dark:border-gray-500 rounded-md dark:text-gray-300"
            />
          </div>
        </div>

        <div class="my-4">
          <label
            for={f[:password_confirmation].name}
            class="block font-medium text-gray-700 dark:text-gray-300"
          >
            Confirm password
          </label>
          <div class="mt-1">
            <.input
              type="password"
              autocomplete="new-password"
              field={f[:password_confirmation]}
              phx-debounce={200}
              class="dark:bg-gray-900 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full border-gray-300 dark:border-gray-500 rounded-md dark:text-gray-300"
            />
          </div>
        </div>

        <%= if PlausibleWeb.Captcha.enabled?() do %>
          <div class="mt-4">
            <div
              phx-update="ignore"
              id="hcaptcha-placeholder"
              class="h-captcha"
              data-sitekey={PlausibleWeb.Captcha.sitekey()}
            >
            </div>
            <%= if @captcha_error do %>
              <div class="text-red-500 text-xs italic mt-3" x-data x-init="hcaptcha.reset()">
                <%= @captcha_error %>
              </div>
            <% end %>
            <script
              phx-update="ignore"
              id="hcaptcha-script"
              src="https://hcaptcha.com/1/api.js"
              async
              defer
            >
            </script>
          </div>
        <% end %>

        <% submit_text =
          if ce?() or @invitation do
            "Create my account"
          else
            "Start my free trial"
          end %>
        <.button id="register" disabled={@disable_submit} type="submit" class="mt-4 w-full">
          <%= submit_text %>
        </.button>

        <p class="text-center text-gray-600 dark:text-gray-500  mt-4">
          Already have an account?
          <.styled_link href="/login">
            Log in
          </.styled_link>
        </p>
      </.form>
    </.focus_box>
    """
  end

  defp name_input(assigns) do
    ~H"""
    <div class="my-4">
      <label for={@field.name} class="block font-medium text-gray-700 dark:text-gray-300">
        Full name
      </label>
      <div class="mt-1">
        <.input
          field={@field}
          placeholder="Jane Doe"
          phx-debounce={200}
          class="dark:bg-gray-900 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full border-gray-300 dark:border-gray-500 rounded-md dark:text-gray-300"
        />
      </div>
    </div>
    """
  end

  defp email_input(assigns) do
    email_classes = ~w(
      dark:bg-gray-900
      shadow-sm
      focus:ring-indigo-500
      focus:border-indigo-500
      block
      w-full
      border-gray-300
      dark:border-gray-500
      rounded-md
      dark:text-gray-300
    )

    {email_readonly, email_extra_classes} =
      if assigns[:for_invitation] do
        {[readonly: "readonly"], ["bg-gray-100"]}
      else
        {[], []}
      end

    assigns =
      assigns
      |> assign(:email_readonly, email_readonly)
      |> assign(:email_classes, email_classes ++ email_extra_classes)

    ~H"""
    <div class="my-4">
      <div class="flex justify-between">
        <label for={@field.name} class="block font-medium text-gray-700 dark:text-gray-300">
          Email
        </label>
        <p class="text-xs text-gray-500 mt-1">No spam, guaranteed.</p>
      </div>
      <div class="mt-1">
        <.input
          type="email"
          field={@field}
          placeholder="example@email.com"
          phx-debounce={200}
          class={@email_classes}
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
         PlausibleWeb.Captcha.verify(params["h-captcha-response"]) do
      user =
        params["user"]
        |> Map.put("email", invitation.email)
        |> Auth.User.new()

      with_team? = invitation.role == :owner

      add_user(socket, user, with_team?: with_team?)
    else
      {:noreply, assign(socket, :captcha_error, "Please complete the captcha to register")}
    end
  end

  def handle_event("register", %{"user" => _} = params, socket) do
    if not PlausibleWeb.Captcha.enabled?() or
         PlausibleWeb.Captcha.verify(params["h-captcha-response"]) do
      user = Auth.User.new(params["user"])

      add_user(socket, user)
    else
      {:noreply, assign(socket, :captcha_error, "Please complete the captcha to register")}
    end
  end

  def handle_event("send-metrics-after", _params, socket) do
    {:noreply, assign(socket, trigger_submit: true)}
  end

  defp add_user(socket, user, opts \\ []) do
    result =
      Repo.transaction(fn ->
        do_add_user(user, opts)
      end)

    case result do
      {:ok, _user} ->
        socket = assign(socket, disable_submit: true)

        on_ee do
          event_name = "Signup#{if socket.assigns.invitation, do: " via invitation"}"
          {:noreply, push_event(socket, "send-metrics", %{event_name: event_name})}
        else
          {:noreply, assign(socket, trigger_submit: true)}
        end

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
             find_invitation_by_id_unified(invitation_or_transfer_id) do
        find_transfer_by_id_unified(invitation_or_transfer_id)
      end

    case result do
      {:error, :invitation_not_found} -> nil
      {:ok, unified} -> unified
    end
  end

  defp find_invitation_by_id_unified(id) do
    invitation =
      Teams.GuestInvitation
      |> Repo.get_by(invitation_id: id)
      |> Repo.preload([:site, team_invitation: :inviter])

    case invitation do
      nil ->
        {:error, :invitation_not_found}

      guest_invitation ->
        {:ok,
         %{
           role: guest_invitation.role,
           email: guest_invitation.team_invitation.email
         }}
    end
  end

  defp find_transfer_by_id_unified(id) do
    transfer =
      Teams.SiteTransfer
      |> Repo.get_by(transfer_id: id)
      |> Repo.preload([:site, :initiator])

    case transfer do
      nil ->
        {:error, :invitation_not_found}

      transfer ->
        {:ok,
         %{
           role: :owner,
           email: transfer.email
         }}
    end
  end
end
