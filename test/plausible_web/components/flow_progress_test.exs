defmodule PlausibleWeb.Components.FlowProgressTest do
  use Plausible.DataCase

  import Phoenix.LiveViewTest, only: [render_component: 2]

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
        current_step: "Add site info"
      )

    assert_dot_labels(rendered, ["Add site info", "Install Plausible"])

    assert_current_step(rendered, "Add site info")
  end

  test "invitation" do
    rendered =
      render_component(&FlowProgress.render/1,
        flow: PlausibleWeb.Flows.invitation(),
        current_step: "Register"
      )

    assert_dot_labels(rendered, ["Register", "Activate account"])
    assert_current_step(rendered, "Register")
  end

  test "provisioning" do
    rendered =
      render_component(&FlowProgress.render/1,
        flow: PlausibleWeb.Flows.provisioning(),
        current_step: "Add site info"
      )

    assert_dot_labels(rendered, ["Add site info", "Install Plausible"])

    assert_current_step(rendered, "Add site info")
  end

  test "review" do
    rendered =
      render_component(&FlowProgress.render/1,
        flow: PlausibleWeb.Flows.review(),
        current_step: "Install Plausible"
      )

    assert_dot_labels(rendered, ["Install Plausible"])
    assert_current_step(rendered, "Install Plausible")
  end

  test "domain_change" do
    rendered =
      render_component(&FlowProgress.render/1,
        flow: PlausibleWeb.Flows.domain_change(),
        current_step: "Set up new domain"
      )

    assert_dot_labels(rendered, ["Set up new domain", "Install Plausible"])

    assert_current_step(rendered, "Set up new domain")
  end

  defp assert_dot_labels(rendered, expected_labels) do
    labels =
      rendered
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#flow-progress [aria-label]")
      |> LazyHTML.attribute("aria-label")

    assert labels == expected_labels
  end

  defp assert_current_step(rendered, expected_label) do
    current =
      rendered
      |> LazyHTML.from_fragment()
      |> LazyHTML.query(~s(#flow-progress [aria-current="step"]))

    assert Enum.count(current) == 1
    assert LazyHTML.attribute(current, "aria-label") == [expected_label]
  end
end
