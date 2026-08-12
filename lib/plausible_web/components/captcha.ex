defmodule PlausibleWeb.Components.Captcha do
  @moduledoc """
  Friendly Captcha widget shared between the registration and password-reset forms.
  """
  use Phoenix.Component, global_prefixes: ~w(x-)

  @reset_event "reset-frc-captcha"

  @doc """
  Tells the client to discard the current captcha solution and solve a new one.
  """
  def reset(socket) do
    if PlausibleWeb.Captcha.enabled?() do
      Phoenix.LiveView.push_event(socket, @reset_event, %{})
    else
      socket
    end
  end

  attr :live?, :boolean, default: false
  attr :error, :string, default: nil

  def widget(assigns) do
    assigns = assign(assigns, :reset_event, @reset_event)

    ~H"""
    <div>
      <div
        phx-update={if @live?, do: "ignore"}
        id="frc-captcha-placeholder"
        class="frc-captcha hidden mb-2"
        data-sitekey={PlausibleWeb.Captcha.sitekey()}
        data-start="auto"
        style="width: 100%"
      >
      </div>
      <p :if={@error} class="text-xs text-red-500 mt-2">
        {@error}
      </p>
      <p class="text-xs text-gray-500 dark:text-gray-400">
        This site is protected by
        <PlausibleWeb.Components.Generic.styled_link href="https://friendlycaptcha.com" new_tab={true}>
          Friendly Captcha
        </PlausibleWeb.Components.Generic.styled_link>
      </p>
      <script
        phx-update={if @live?, do: "ignore"}
        id="frc-captcha-script"
        type="module"
        src={
          PlausibleWeb.Router.Helpers.static_path(
            PlausibleWeb.Endpoint,
            "/js/friendly-captcha/site.min.js"
          )
        }
        async
        defer
      >
      </script>
      <script
        phx-update={if @live?, do: "ignore"}
        id="frc-captcha-script-compat"
        nomodule
        src={
          PlausibleWeb.Router.Helpers.static_path(
            PlausibleWeb.Endpoint,
            "/js/friendly-captcha/site.compat.min.js"
          )
        }
        async
        defer
      >
      </script>
      <script phx-update={if @live?, do: "ignore"} id="frc-captcha-reveal">
        (function () {
          var SHOW_AFTER_LONG_WAIT_MS = 5000;
          var el = document.getElementById("frc-captcha-placeholder");
          if (!el) return;

          // Match the widget to the app's resolved light/dark theme. This runs
          // before the (deferred) SDK initializes, so the widget picks up the
          // right theme from the start, and the observer keeps it in sync.
          function applyTheme() {
            el.dataset.theme =
              document.documentElement.classList.contains("dark") ? "dark" : "light";
          }
          applyTheme();
          new MutationObserver(applyTheme).observe(document.documentElement, {
            attributes: true,
            attributeFilter: ["class"]
          });

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

          window.addEventListener("phx:<%= @reset_event %>", function () {
            if (!window.frcaptcha) return;
            window.frcaptcha.getAllWidgets().forEach(function (widget) {
              if (!widget.isDestroyed) widget.reset();
            });
          });
        })();
      </script>
    </div>
    """
  end
end
