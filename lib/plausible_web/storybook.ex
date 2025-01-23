defmodule PlausibleWeb.Storybook do
  @moduledoc false

  use PhoenixStorybook,
    otp_app: :plausible_web,
    title: "Plausible Storybook",
    content_path: Path.expand("../../storybook", __DIR__),
    # assets path are remote path, not local file-system paths
    css_path: "/css/storybook.css",
    js_path: "/js/storybook.js",
    sandbox_class: "plausible",
    color_mode: true
end
