defmodule PlausibleWeb.Live.Components.FormTest do
  use PlausibleWeb.ConnCase, async: true
  import Plausible.LiveViewTest, only: [render_component: 2]
  import Plausible.Test.Support.HTML

  alias Plausible.Auth.User
  alias PlausibleWeb.Live.Components.Form

  describe "password_input_with_strength/1" do
    test "renders for correct, strong password" do
      doc = render_password_input_with_strength("very-secret-and-very-long-123")

      assert element_exists?(doc, ~s/input#user_password[type="password"][name="user[password]"]/)
      assert element_exists?(doc, ~s/div.rounded-full.bg-indigo-600/)
      refute element_exists?(doc, "label")
      refute element_exists?(doc, "p")
    end

    test "renders with label when passed" do
      doc =
        render_password_input_with_strength(
          "very-secret-and-very-long-123",
          label: "New password"
        )

      assert element_exists?(doc, ~s/input#user_password[type="password"][name="user[password]"]/)
      assert element_exists?(doc, ~s/label[for="user_password"]/)
      assert text_of_element(doc, ~s/label[for="user_password"]/) == "New password"
    end

    test "renders weak password warning and hints when password too short" do
      doc = render_password_input_with_strength("too-short")

      assert [warning_p, hint_p] = find(doc, "p")
      assert text(warning_p) == "Password is too weak"
      assert text(hint_p) != ""
    end

    test "does not render hints and suggestions paragraph when there's none" do
      doc =
        render_password_input_with_strength("very-secret-but-too-short",
          strength: %{
            score: 2,
            warning: "",
            suggestions: []
          }
        )

      assert [warning_p] = find(doc, "p")
      assert text(warning_p) == "Password is too weak"
    end

    test "renders too long password case gracefully" do
      too_long_password = String.duplicate("very-long-very-secret-1234567890", 10)
      doc = render_password_input_with_strength(too_long_password)

      assert [error_p] = find(doc, "p")
      assert text(error_p) =~ "cannot be longer than"
    end
  end

  describe "password_length_hint/1" do
    test "renders for long enough password" do
      doc = render_password_length_hint("very-secret-and-very-long-123", 12)

      assert [p_hint] = find(doc, "p")
      assert text_of_attr(p_hint, "class") =~ "text-gray-500"
      assert text(p_hint) == "Min 12 characters"
    end

    test "renders for too short password" do
      doc = render_password_length_hint("too-short", 12)

      assert [p_hint] = find(doc, "p")
      assert text_of_attr(p_hint, "class") =~ "text-red-500"
      assert text(p_hint) == "Min 12 characters"
    end

    test "renders gracefully for too long password" do
      too_long_password = String.duplicate("very-long-very-secret-1234567890", 10)
      doc = render_password_length_hint(too_long_password, 12)

      assert [p_hint] = find(doc, "p")
      assert text_of_attr(p_hint, "class") =~ "text-gray-500"
      assert text(p_hint) == "Min 12 characters"
    end
  end

  describe "strength_meter/1" do
    test "renders too weak level" do
      doc = render_component(&Form.strength_meter/1, score: 0, warning: "", suggestions: [])
      meter = find(doc, "div.rounded-full")

      assert text_of_attr(meter, "style") == "width: 0%"
      assert [p_warning] = find(doc, "p")
      assert text(p_warning) == "Password is too weak"
    end

    test "renders very weak level" do
      doc = render_component(&Form.strength_meter/1, score: 1, warning: "", suggestions: [])
      meter = find(doc, "div.rounded-full")

      assert text_of_attr(meter, "style") == "width: 25%"
      assert [p_warning] = find(doc, "p")
      assert text(p_warning) == "Password is too weak"
    end

    test "renders somewhat weak level" do
      doc = render_component(&Form.strength_meter/1, score: 2, warning: "", suggestions: [])
      meter = find(doc, "div.rounded-full")

      assert text_of_attr(meter, "style") == "width: 50%"
      assert [p_warning] = find(doc, "p")
      assert text(p_warning) == "Password is too weak"
    end

    test "renders strong level" do
      doc = render_component(&Form.strength_meter/1, score: 3, warning: "", suggestions: [])
      meter = find(doc, "div.rounded-full")

      assert text_of_attr(meter, "style") == "width: 75%"
      assert find(doc, "p") == []
    end

    test "renders very strong level" do
      doc = render_component(&Form.strength_meter/1, score: 4, warning: "", suggestions: [])
      meter = find(doc, "div.rounded-full")

      assert text_of_attr(meter, "style") == "width: 100%"
      assert find(doc, "p") == []
    end

    test "renders hints paragraph when warning hint is present" do
      doc =
        render_component(&Form.strength_meter/1,
          score: 2,
          warning: "Test warning hint",
          suggestions: []
        )

      assert [_p_warning, p_hint] = find(doc, "p")
      assert text(p_hint) == "Test warning hint."
    end

    test "renders only first suggestion when no warning present" do
      doc =
        render_component(&Form.strength_meter/1,
          score: 2,
          warning: "",
          suggestions: ["Test suggestion 1.", "Test suggestion 2."]
        )

      assert [_p_warning, p_hint] = find(doc, "p")
      assert text(p_hint) =~ "Test suggestion 1."
      refute text(p_hint) =~ "Test suggestion 2."
    end

    @tag :slow
    test "favors hint warning over suggestion when both present" do
      doc =
        render_component(&Form.strength_meter/1,
          score: 2,
          warning: "Test warning hint",
          suggestions: ["Test suggestion 1.", "Test suggestion 2."]
        )

      assert [_p_warning, p_hint] = find(doc, "p")
      assert text(p_hint) =~ "Test warning hint."
      refute text(p_hint) =~ "Test suggestion 1."
      refute text(p_hint) =~ "Test suggestion 2."
    end
  end

  defp render_password_input_with_strength(password, attrs \\ []) do
    changeset =
      %{"password" => password}
      |> User.new()
      |> Map.put(:action, :validate)

    strength = User.password_strength(changeset)
    form = Phoenix.Component.to_form(changeset)

    render_component(
      &Form.password_input_with_strength/1,
      Keyword.merge([field: form[:password], strength: strength], attrs)
    )
  end

  defp render_password_length_hint(password, minimum) do
    changeset =
      %{"password" => password}
      |> User.new()
      |> Map.put(:action, :validate)

    form = Phoenix.Component.to_form(changeset)

    render_component(&Form.password_length_hint/1, field: form[:password], minimum: minimum)
  end
end
