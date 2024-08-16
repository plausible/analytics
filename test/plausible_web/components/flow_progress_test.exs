defmodule PlausibleWeb.Components.FlowProgressTest do
  use Plausible.DataCase

  import Plausible.LiveViewTest, only: [render_component: 2]
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
        flow: "register",
        current_step: "Register"
      )

    assert text_of_element(rendered, "#flow-progress") ==
             "1 Register 2 Activate account 3 Add site info 4 Install snippet 5 Verify snippet"
  end

  test "invitation" do
    rendered =
      render_component(&FlowProgress.render/1,
        flow: "invitation",
        current_step: "Register"
      )

    assert text_of_element(rendered, "#flow-progress") ==
             "1 Register 2 Activate account"
  end

  test "provisioning" do
    rendered =
      render_component(&FlowProgress.render/1,
        flow: "provisioning",
        current_step: "Add site info"
      )

    assert text_of_element(rendered, "#flow-progress") ==
             "1 Add site info 2 Install snippet 3 Verify snippet"
  end
end
