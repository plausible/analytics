defmodule PlausibleWeb.Components.Captcha do
  @moduledoc """
  Friendly Captcha widget shared between the registration and password-reset forms.

  Renders the (invisible) widget placeholder, the SDK script tags, and the reveal
  script that:

    * matches the widget to the app's resolved light/dark theme,
    * reveals the widget only when the user must interact (or on error/slow solve),
    * dispatches `frc-captcha-ready` / `frc-captcha-reset` window events so the
      submit button can gate on a valid solution.

  Pass `live?={true}` from a LiveView so the widget and scripts carry
  `phx-update="ignore"` and survive DOM patching.
  """
  use Phoenix.Component, global_prefixes: ~w(x-)

  attr :live?, :boolean, default: false
  attr :error, :string, default: nil
  slot :attribution, required: true

  def widget(assigns) do
    ~H"""
    <div>
      <div
        phx-update={if @live?, do: "ignore"}
        id="frc-captcha-placeholder"
        class="frc-captcha hidden"
        data-sitekey={PlausibleWeb.Captcha.sitekey()}
        data-start="auto"
      >
      </div>
      <p :if={@error} class="text-xs text-red-500 mt-2">
        {@error}
      </p>
      {render_slot(@attribution)}
      <script
        phx-update={if @live?, do: "ignore"}
        id="frc-captcha-script"
        type="module"
        src="https://cdn.jsdelivr.net/npm/@friendlycaptcha/sdk@1/site.min.js"
        async
        defer
      >
      </script>
      <script
        phx-update={if @live?, do: "ignore"}
        id="frc-captcha-script-compat"
        nomodule
        src="https://cdn.jsdelivr.net/npm/@friendlycaptcha/sdk@1/site.compat.min.js"
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
        })();
      </script>
    </div>
    """
  end
end
