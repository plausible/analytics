defmodule PlausibleWeb.Live.Components.VerificationTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  @component PlausibleWeb.Live.Components.Verification
  @progress ~s|div#progress|

  @pulsating_circle ~s|div#progress-indicator div.pulsating-circle|
  @check_circle ~s|div#progress-indicator #check-circle|
  @shuttle ~s|div#progress-indicator svg#shuttle|
  @recommendations ~s|div#recommendations .recommendation|

  test "renders initial state" do
    html = render_component(@component, domain: "example.com")
    assert element_exists?(html, @progress)

    assert text_of_element(html, @progress) ==
             "We're visiting your site to ensure that everything is working correctly"

    assert element_exists?(html, ~s|a[href="/example.com/snippet"]|)
    assert element_exists?(html, ~s|a[href="/example.com/settings/general"]|)
    assert element_exists?(html, @pulsating_circle)
    refute class_of_element(html, @pulsating_circle) =~ "hidden"
    refute element_exists?(html, @recommendations)
    refute element_exists?(html, @check_circle)
  end

  test "renders shuttle on error" do
    html = render_component(@component, domain: "example.com", success?: false, finished?: true)
    refute element_exists?(html, @pulsating_circle)
    refute element_exists?(html, @check_circle)
    refute element_exists?(html, @recommendations)
    assert element_exists?(html, @shuttle)
  end

  test "renders diagnostic rating" do
    rating =
      Plausible.Verification.Checks.interpret_diagnostics(%Plausible.Verification.State{
        url: "example.com"
      })

    html =
      render_component(@component,
        domain: "example.com",
        success?: false,
        finished?: true,
        rating: rating
      )

    recommendations = html |> find(@recommendations) |> Enum.map(&text/1)

    assert recommendations == [
             "If your site is running at a different location, please manually check your integration - Learn more"
           ]
  end

  test "hides pulsating circle when finished in a modal, shows check circle" do
    html =
      render_component(@component,
        domain: "example.com",
        modal?: true,
        success?: true,
        finished?: true
      )

    assert class_of_element(html, @pulsating_circle) =~ "hidden"
    assert element_exists?(html, @check_circle)
  end

  test "renders a progress message" do
    html = render_component(@component, domain: "example.com", message: "Arbitrary message")

    assert text_of_element(html, @progress) == "Arbitrary message"
  end

  test "renders contact link on >3 attempts" do
    html = render_component(@component, domain: "example.com", attempts: 2, finished?: true)
    refute html =~ "Need further help with your integration?"
    refute element_exists?(html, ~s|a[href="https://plausible.io/contact"]|)

    html = render_component(@component, domain: "example.com", attempts: 3, finished?: true)
    assert html =~ "Need further help with your integration?"
    assert element_exists?(html, ~s|a[href="https://plausible.io/contact"]|)
  end
end
