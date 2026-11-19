defmodule PlausibleE2E.Dashboard.TeamManagementTest do
  use PlausibleE2E.Case, async: true

  defp create_team(page) do
    Page.goto!(page, "/team/setup", wait_until: :commit)
    expect_live_view_connected(page)
    Page.get_by_role(page, :button, name: "Create team") |> Locator.click!()
    Expect.to_have_url!(page, ~r/\/settings\/team\/general/)
    expect_live_view_connected(page)
    # so that tests start without a flash
    close_flash_message(page)
  end

  defp submit_invite_form(page, email, role_option_name) do
    Page.get_by_placeholder(page, "Enter e-mail") |> Locator.fill!(email)
    Page.locator(page, "#input-role-picker-trigger") |> Locator.click!()

    page
    |> Page.locator("#input-role-picker")
    |> Locator.get_by_role(:option, name: role_option_name)
    |> Locator.click!()

    Page.get_by_role(page, :button, name: "Invite") |> Locator.click!()
    # so that tests continue without a flash
    has_flash_message(page, "#{email} has been invited")
    close_flash_message(page)
  end

  defp expect_dialogs(dialogs, n), do: assert(length(Agent.get(dialogs, & &1)) == n)

  test "lowering your own role asks for confirmation", %{page: page, request: request} do
    %{user: user} = setup_site(page: page, request: request)
    create_team(page)

    # The only owner can't change their own role, so a second (invited) owner
    # is needed for the self-demotion options to become selectable.
    owner_email = "owner-#{random_id()}@example.com"
    submit_invite_form(page, owner_email, ~r/^Owner/)

    Expect.to_contain_text!(
      Page.get_by_role(page, :button, name: "Role for #{owner_email}:"),
      "Owner"
    )

    trigger = Page.get_by_role(page, :button, name: "Role for #{user.email}:")
    options = Page.get_by_role(page, :listbox, name: "Role for #{user.email}:")
    viewer = fn -> Locator.get_by_role(options, :option, name: ~r/^Viewer/) end

    {:ok, dialogs} = Agent.start_link(fn -> [] end)

    answer_next_dialog = fn accept ->
      Page.once(page, :dialog, fn dialog ->
        Agent.update(dialogs, &(&1 ++ [Dialog.message(dialog)]))
        if accept, do: Dialog.accept(dialog), else: Dialog.dismiss(dialog)
      end)
    end

    key = fn k -> Keyboard.press!(Page.keyboard(page), k) end

    Expect.to_be_enabled!(trigger)
    Expect.to_contain_text!(trigger, "Owner")

    Test.step "lower your own role, but cancel the confirmation dialog (mouse)" do
      answer_next_dialog.(false)

      Locator.click!(trigger)
      Locator.click!(viewer.())

      expect_dialogs(dialogs, 1)
      assert Agent.get(dialogs, &hd/1) =~ "You're about to lower your own role"
      Expect.to_contain_text!(trigger, "Owner")
      has_no_flash_message(page)

      # Close the listbox that remained open because the option selection click didn't
      # go through -- our confirmation dialog prevented it from bubbling up to Prima.
      key.("Escape")
    end

    Test.step "lower your own role, but cancel the confirmation dialog (keyboard)" do
      answer_next_dialog.(false)

      Locator.focus!(trigger)
      key.("ArrowUp")
      Expect.to_have_attribute!(viewer.(), "data-focus")
      key.("Enter")

      expect_dialogs(dialogs, 2)
      Expect.to_contain_text!(trigger, "Owner")
      has_no_flash_message(page)

      key.("Escape")
    end

    Test.step "lower your own role and confirm (mouse)" do
      answer_next_dialog.(true)

      Locator.click!(trigger)
      Locator.click!(viewer.())

      # The change reaches the server, which rejects it: the other owner has only
      # been invited so far.
      has_flash_message(page, "The team has to have at least one owner")

      # asked once: phoenix_html must not ask again as the confirmed click bubbles up
      expect_dialogs(dialogs, 3)

      # Known bug, to be fixed soon: the trigger keeps showing the rejected role
      # until the page is reloaded. Once fixed, the reload won't be necessary.
      Page.reload!(page)
      expect_live_view_connected(page)

      Expect.to_contain_text!(trigger, "Owner")
    end

    Test.step "lower your own role and confirm (keyboard)" do
      answer_next_dialog.(true)

      Locator.focus!(trigger)
      key.("ArrowUp")
      Expect.to_have_attribute!(viewer.(), "data-focus")
      key.("Enter")

      has_flash_message(page, "The team has to have at least one owner")

      expect_dialogs(dialogs, 4)

      Page.reload!(page)
      expect_live_view_connected(page)

      Expect.to_contain_text!(trigger, "Owner")
    end
  end

  test "choosing the current role again just closes the listbox", %{page: page, request: request} do
    setup_site(page: page, request: request)
    create_team(page)

    viewer_email = "viewer-#{random_id()}@example.com"
    submit_invite_form(page, viewer_email, ~r/^Viewer/)

    trigger = Page.get_by_role(page, :button, name: "Role for #{viewer_email}:")
    options = Page.get_by_role(page, :listbox, name: "Role for #{viewer_email}:")

    Expect.to_contain_text!(trigger, "Viewer")

    {:ok, dialogs} = Agent.start_link(fn -> [] end)

    Page.on(page, :dialog, fn dialog ->
      Agent.update(dialogs, &(&1 ++ [Dialog.message(dialog)]))
      Dialog.dismiss(dialog)
    end)

    Locator.click!(trigger)
    options |> Locator.get_by_role(:option, name: ~r/^Viewer/) |> Locator.click!()

    Expect.to_have_attribute!(trigger, "aria-expanded", "false")
    Expect.to_contain_text!(trigger, "Viewer")
    expect_dialogs(dialogs, 0)
    has_no_flash_message(page)
  end
end
