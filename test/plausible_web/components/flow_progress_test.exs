defmodule PlausibleWeb.Components.FlowProgressTest do
  use Plausible.DataCase

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias PlausibleWeb.Components.FlowProgress

  @steps ["A", "B", "C", "D"]

  test "marks steps before, at, and after the current step correctly" do
    rendered =
      render_component(&FlowProgress.render/1,
        steps: @steps,
        current_step: "B"
      )

    assert_dot_labels(rendered, @steps)
    assert_current_step(rendered, "B")

    assert_dot_classes(rendered, [
      {"A", FlowProgress.dot_class(:completed)},
      {"B", FlowProgress.dot_class(:current)},
      {"C", FlowProgress.dot_class(:upcoming)},
      {"D", FlowProgress.dot_class(:upcoming)}
    ])
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

  defp assert_dot_classes(rendered, expected_label_class_pairs) do
    html = LazyHTML.from_fragment(rendered)

    Enum.each(expected_label_class_pairs, fn {label, expected_class} ->
      assert html
             |> LazyHTML.query(~s(#flow-progress [aria-label="#{label}"]))
             |> LazyHTML.attribute("class") == [expected_class]
    end)
  end
end
