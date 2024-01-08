defmodule PlausibleWeb.Live.RegisterForm do
  @moduledoc """
  LiveView for registration form.
  """

  use PlausibleWeb, :live_view
  use Phoenix.HTML
  import PlausibleWeb.Live.Components.Form

  alias Plausible.Auth
  alias Plausible.Repo

  def mount(params, _session, socket) do
    socket =
      assign_new(socket, :invitation, fn ->
        if invitation_id = params["invitation_id"] do
          Repo.get_by(Auth.Invitation, invitation_id: invitation_id)
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
         trigger_submit: false
       )}
    end
  end

  def render(%{invitation_expired: true} = assigns) do
    ~H"""
    <div class="mx-auto mt-6 text-center dark:text-gray-300">
      <h1 class="text-3xl font-black">Plausible Analytics</h1>
      <div class="text-xl font-medium">Lightweight and privacy-friendly web analytics</div>
    </div>

    <div class="w-full max-w-md mx-auto bg-white dark:bg-gray-800 shadow-md rounded px-8 py-6 mb-4 mt-8">
      <h2 class="text-xl font-black dark:text-gray-100">Invitation expired</h2>

      <p class="mt-4 text-sm">
        Your invitation has expired or been revoked. Please request fresh one or you can <%= link(
          "sign up",
          class: "text-indigo-600 hover:text-indigo-900",
          to: Routes.auth_path(@socket, :register)
        ) %> for a 30-day unlimited free trial without an invitation.
      </p>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto mt-6 text-center dark:text-gray-300">
      <h1 class="text-3xl font-black">
        <%= if small_build?() or @live_action == :register_from_invitation_form do %>
          Register your Plausible Analytics account
        <% else %>
          Register your 30-day free trial
        <% end %>
      </h1>
      <div class="text-xl font-medium">Set up privacy-friendly analytics with just a few clicks</div>
    </div>

    <div class="w-full max-w-3xl mt-4 mx-auto flex flex-shrink-0">
      <.form
        :let={f}
        for={@form}
        id="register-form"
        phx-hook="Metrics"
        phx-change="validate"
        phx-submit="register"
        phx-trigger-action={@trigger_submit}
        class="w-full max-w-md mx-auto bg-white dark:bg-gray-800 shadow-md rounded px-8 py-6 mb-4 mt-8"
      >
        <input name="_csrf_token" type="hidden" value={Plug.CSRFProtection.get_csrf_token()} />

        <h2 class="text-xl font-black dark:text-gray-100">Enter your details</h2>

        <%= if @invitation do %>
          <.email_input field={f[:email]} for_invitation={true} />
          <.name_input field={f[:name]} />
        <% else %>
          <.name_input field={f[:name]} />
          <.email_input field={f[:email]} for_invitation={false} />
        <% end %>

        <div class="my-4">
          <div class="flex justify-between">
            <label
              for={f[:password].name}
              class="block text-sm font-medium text-gray-700 dark:text-gray-300"
            >
              Password
            </label>
            <.password_length_hint minimum={12} field={f[:password]} />
          </div>
          <div class="mt-1">
            <.password_input_with_strength
              field={f[:password]}
              strength={@password_strength}
              phx-debounce={200}
              class="dark:bg-gray-900 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:text-gray-300"
            />
          </div>
        </div>

        <div class="my-4">
          <label
            for={f[:password_confirmation].name}
            class="block text-sm font-medium text-gray-700 dark:text-gray-300"
          >
            Password confirmation
          </label>
          <div class="mt-1">
            <.input
              type="password"
              autocomplete="new-password"
              field={f[:password_confirmation]}
              phx-debounce={200}
              class="dark:bg-gray-900 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:text-gray-300"
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
              <div class="text-red-500 text-xs italic mt-3"><%= @captcha_error %></div>
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
          if small_build?() or @invitation do
            "Create my account →"
          else
            "Start my free trial →"
          end %>
        <PlausibleWeb.Components.Generic.button id="register" type="submit" class="mt-4 w-full">
          <%= submit_text %>
        </PlausibleWeb.Components.Generic.button>

        <p class="text-center text-gray-600 dark:text-gray-500  text-xs mt-4">
          Already have an account? <%= link("Log in",
            to: "/login",
            class: "underline text-gray-800 dark:text-gray-50"
          ) %> instead.
        </p>
      </.form>
      <div :if={@live_action == :register_form} class="pt-12 pl-8 hidden md:block">
        <%= PlausibleWeb.AuthView.render("_onboarding_steps.html", current_step: 0) %>
      </div>
    </div>
    """
  end

  defp name_input(assigns) do
    ~H"""
    <div class="my-4">
      <label for={@field.name} class="block text-sm font-medium text-gray-700 dark:text-gray-300">
        Full name
      </label>
      <div class="mt-1">
        <.input
          field={@field}
          placeholder="Jane Doe"
          phx-debounce={200}
          class="dark:bg-gray-900 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:text-gray-300"
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
      sm:text-sm
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
        <label for={@field.name} class="block text-sm font-medium text-gray-700 dark:text-gray-300">
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

    {:noreply, assign(socket, form: to_form(changeset), password_strength: password_strength)}
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

      user =
        case invitation.role do
          :owner -> user
          _ -> Plausible.Auth.User.remove_trial_expiry(user)
        end

      add_user(socket, user)
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

  defp add_user(socket, user) do
    case Repo.insert(user) do
      {:ok, _user} ->
        metrics_params =
          if socket.assigns.invitation do
            %{
              event_name: "Signup via invitation",
              params: %{u: "/register/invitation/:invitation_id"}
            }
          else
            %{event_name: "Signup", params: %{}}
          end

        {:noreply, push_event(socket, "send-metrics", metrics_params)}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(Map.put(changeset, :action, :validate))
         )}
    end
  end
end
