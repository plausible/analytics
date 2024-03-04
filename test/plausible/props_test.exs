defmodule Plausible.PropsTest do
  use Plausible.DataCase

  test "allow/2 returns error when user plan does not include props" do
    user = insert(:user, subscription: build(:growth_subscription))
    site = insert(:site, members: [user])

    assert {:error, :upgrade_required} = Plausible.Props.allow(site, "my-prop-1")
    assert %Plausible.Site{allowed_event_props: nil} = Plausible.Repo.reload!(site)
  end

  test "allow/2 adds props to the array" do
    site = insert(:site)

    assert {:ok, site} = Plausible.Props.allow(site, "my-prop-1")
    assert {:ok, site} = Plausible.Props.allow(site, "my-prop-2")

    assert %Plausible.Site{allowed_event_props: ["my-prop-2", "my-prop-1"]} =
             Plausible.Repo.reload!(site)
  end

  test "allow/2 takes a single prop or multiple" do
    site = insert(:site)

    assert {:ok, site} = Plausible.Props.allow(site, "my-prop-1")
    assert {:ok, site} = Plausible.Props.allow(site, ["my-prop-3", "my-prop-2"])

    assert %Plausible.Site{allowed_event_props: ["my-prop-3", "my-prop-2", "my-prop-1"]} =
             Plausible.Repo.reload!(site)
  end

  test "allow/2 trims trailing whitespaces" do
    site = insert(:site)

    assert {:ok, site} = Plausible.Props.allow(site, "   my-prop-1 ")
    assert %Plausible.Site{allowed_event_props: ["my-prop-1"]} = Plausible.Repo.reload!(site)
  end

  test "allow/2 fails when prop list is too long" do
    site = insert(:site)
    props = for i <- 1..300, do: "my-prop-#{i}"

    assert {:ok, site} = Plausible.Props.allow(site, props)
    assert {:error, changeset} = Plausible.Props.allow(site, "my-prop-301")

    assert {"should have at most %{count} item(s)",
            [count: 300, validation: :length, kind: :max, type: :list]} ==
             changeset.errors[:allowed_event_props]
  end

  test "allow/2 fails when prop key is too long" do
    site = insert(:site)

    long_prop = String.duplicate("a", 301)
    assert {:error, changeset} = Plausible.Props.allow(site, long_prop)
    assert {"must be between 1 and 300 characters", []} == changeset.errors[:allowed_event_props]
  end

  test "allow/2 fails when prop key is empty" do
    site = insert(:site)

    assert {:error, changeset} = Plausible.Props.allow(site, "")
    assert {"must be between 1 and 300 characters", []} == changeset.errors[:allowed_event_props]

    assert {:error, changeset} = Plausible.Props.allow(site, " ")
    assert {"must be between 1 and 300 characters", []} == changeset.errors[:allowed_event_props]
  end

  test "allow/2 does not fail when prop key is already in the list" do
    site = insert(:site)

    assert {:ok, site} = Plausible.Props.allow(site, "my-prop-1")
    assert {:ok, site} = Plausible.Props.allow(site, "my-prop-1")
    assert %Plausible.Site{allowed_event_props: ["my-prop-1"]} = Plausible.Repo.reload!(site)
  end

  test "disallow/2 removes the prop from the array" do
    site = insert(:site)

    assert {:ok, site} = Plausible.Props.allow(site, "my-prop-1")
    assert {:ok, site} = Plausible.Props.allow(site, "my-prop-2")
    assert {:ok, site} = Plausible.Props.disallow(site, "my-prop-2")
    assert %Plausible.Site{allowed_event_props: ["my-prop-1"]} = Plausible.Repo.reload!(site)
  end

  test "disallow/2 does not fail when prop is not in the list" do
    site = insert(:site)

    assert {:ok, site} = Plausible.Props.allow(site, "my-prop-1")
    assert {:ok, site} = Plausible.Props.disallow(site, "my-prop-2")
    assert %Plausible.Site{allowed_event_props: ["my-prop-1"]} = Plausible.Repo.reload!(site)
  end

  test "allow_existing_props/2 returns error when user plan does not include props" do
    user = insert(:user, subscription: build(:growth_subscription))
    site = insert(:site, members: [user])

    journey site do
      custom_event "Payment", props: %{amount: 500}
      custom_event "Payment", props: %{amount: 100, logged_in: false}
      custom_event "Payment", props: %{amount: 100, is_customer: false}
    end

    assert {:error, :upgrade_required} = Plausible.Props.allow_existing_props(site)
    assert %Plausible.Site{allowed_event_props: nil} = Plausible.Repo.reload!(site)
  end

  test "allow_existing_props/1 saves the most frequent prop keys" do
    site = insert(:site)

    journey site do
      custom_event "Payment", props: %{amount: 500}
      custom_event "Payment", props: %{amount: 100, logged_in: false}
      custom_event "Payment", props: %{amount: 100, is_customer: false}
    end

    {:ok, site} = Plausible.Props.allow_existing_props(site)

    assert %Plausible.Site{allowed_event_props: ["amount", "logged_in", "is_customer"]} =
             Plausible.Repo.reload!(site)
  end

  # test "allow_existing_props/1 skips invalid keys" do
  #   site = insert(:site)
  #   long = String.duplicate("a", 301)

  #   journey site do
  #     custom_event "Payment", props: %{:amount => 500, long => true}
  #     custom_event "Payment", props: %{amount: 100, logged_in: false}
  #     custom_event "Payment", props: %{amount: 100, is_customer: false}
  #   end

  #   {:ok, site} = Plausible.Props.allow_existing_props(site)

  #   assert %Plausible.Site{allowed_event_props: ["amount", "logged_in", "is_customer"]} =
  #            Plausible.Repo.reload!(site)
  # end

  test "allow_existing_props/1 can be run multiple times" do
    site = insert(:site)

    journey site do
      custom_event "Payment", props: %{:amount => 500}
      custom_event "Payment", props: %{amount: 100, logged_in: false}
      custom_event "Payment", props: %{amount: 100, is_customer: false}
    end

    {:ok, %Plausible.Site{allowed_event_props: ["amount", "logged_in", "is_customer"]}} =
      Plausible.Props.allow_existing_props(site)

    journey site do
      custom_event "Payment", props: %{amount: 500, os: "Windows"}
      custom_event "Payment", props: %{amount: 100, logged_in: false, with_error: true}
      custom_event "Payment", props: %{amount: 100, is_customer: false, first_time_customer: true}
    end

    {:ok,
     %Plausible.Site{
       allowed_event_props: [
         "amount",
         "logged_in",
         "is_customer",
         "os",
         "with_error",
         "first_time_customer"
       ]
     }} = Plausible.Props.allow_existing_props(site)
  end

  test "suggest_keys_to_allow/2 returns prop keys from events" do
    site = insert(:site)

    journey site do
      custom_event "Payment", props: %{amount: 500, os: "Windows"}
      custom_event "Payment", props: %{amount: 100, logged_in: false, with_error: true}
      custom_event "Payment", props: %{amount: 100, is_customer: false, first_time_customer: true}
    end

    assert ["amount", "first_time_customer", "is_customer", "logged_in", "os", "with_error"] ==
             site |> Plausible.Props.suggest_keys_to_allow() |> Enum.sort()
  end

  test "suggest_keys_to_allow/2 does not return internal prop keys from special event types" do
    site = insert(:site)

    journey site do
      custom_event "File Download", props: %{url: "http://file.test", logged_in: false}

      custom_event "Outbound Link: Click",
        props: %{url: "http://link.test", first_time_customer: true}

      custom_event "404", props: %{path: "/i-dont-exist", with_error: true}
    end

    assert ["first_time_customer", "logged_in", "with_error"] ==
             site |> Plausible.Props.suggest_keys_to_allow() |> Enum.sort()
  end

  test "configured?/1 returns whether the site has allow at least one prop" do
    site = insert(:site)
    refute Plausible.Props.configured?(site)

    {:ok, site} = Plausible.Props.allow(site, "hello-world")
    assert Plausible.Props.configured?(site)

    {:ok, site} = Plausible.Props.disallow(site, "hello-world")
    refute Plausible.Props.configured?(site)
  end
end
