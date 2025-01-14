defmodule PlausibleWeb.Components.FlowProgressTest do
  use Plausible.DataCase

  import Phoenix.LiveViewTest, only: [render_component: 2]
  import Plausible.Test.Support.HTML

  alias PlausibleWeb.Components.FlowProgress

  test "no flow or unknown flow renders nothing" do
    rendered =
      render_component(&FlowProgress.render/1,
        flow: nil,
        current_step: "unhandled"
      )

    assert rendered == ""

    rendered =
      render_component(&FlowProgress.render/1,
        flow: "unhandled",
        current_step: "unhandled"
      )

    assert rendered == ""
  end

  test "register" do
    rendered =
      render_component(&FlowProgress.render/1,
        flow: PlausibleWeb.Flows.register(),
        current_step: "Register"
      )

    assert text_of_element(rendered, "#flow-progress") ==
             "1 Register 2 Activate account 3 Add site info 4 Install Plausible 5 Verify installation"
  end

  test "invitation" do
    rendered =
      render_component(&FlowProgress.render/1,
        flow: PlausibleWeb.Flows.invitation(),
        current_step: "Register"
      )

    assert text_of_element(rendered, "#flow-progress") ==
             "1 Register 2 Activate account"
  end

  test "provisioning" do
    rendered =
      render_component(&FlowProgress.render/1,
        flow: PlausibleWeb.Flows.provisioning(),
        current_step: "Add site info"
      )

    assert text_of_element(rendered, "#flow-progress") ==
             "1 Add site info 2 Install Plausible 3 Verify installation"
  end

  test "review" do
    rendered =
      render_component(&FlowProgress.render/1,
        flow: PlausibleWeb.Flows.review(),
        current_step: "Install Plausible"
      )

    assert text_of_element(rendered, "#flow-progress") ==
             "1 Install Plausible 2 Verify installation"
  end

  test "domain_change" do
    rendered =
      render_component(&FlowProgress.render/1,
        flow: PlausibleWeb.Flows.domain_change(),
        current_step: "Set up new domain"
      )

    assert text_of_element(rendered, "#flow-progress") ==
             "1 Set up new domain 2 Install Plausible 3 Verify installation"
  end
end
