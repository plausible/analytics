defmodule Plausible.Funnel.DynamicStepTest do
  use Plausible.DataCase, async: true

  @moduletag :ee_only

  on_ee do
    alias Plausible.Funnel
    alias Plausible.Funnel.DynamicStep
    alias Plausible.Funnels

    describe "changeset/1" do
      test "accepts existing struct and turns it to a changeset" do
        site = new_site()

        {:ok, funnel} =
          Funnels.create(site, "Example funnel", [
            %{"event_name" => "Signup"},
            %{"page_path" => "/checkout"}
          ])

        [s1, _] = Funnel.steps(funnel)

        assert %Ecto.Changeset{data: ^s1, valid?: true} = DynamicStep.changeset(s1)
      end

      test "accepts the same params as goal along with step_order" do
        changeset = DynamicStep.changeset(%{"event_name" => "CustomEvent"})
        assert changeset.valid?
        assert %DynamicStep{} == changeset.data
        assert get_change(changeset, :event_name) == "CustomEvent"
        assert is_nil(get_change(changeset, :page_path))

        changeset = DynamicStep.changeset(%{"event_name" => "Purchase", "currency" => "USD"})
        assert changeset.valid?
        assert %DynamicStep{} == changeset.data
        assert get_change(changeset, :event_name) == "Purchase"
        assert get_change(changeset, :currency) == :USD
        assert is_nil(get_change(changeset, :page_path))

        assert changeset =
                 DynamicStep.changeset(%{
                   "page_path" => "/blog",
                   "custom_props" => %{"lang" => "de"}
                 })

        assert changeset.valid?
        assert %DynamicStep{} == changeset.data
        assert get_change(changeset, :page_path) == "/blog"
        assert get_change(changeset, :custom_props) == %{"lang" => "de"}
        assert is_nil(get_change(changeset, :event_name))

        changeset = DynamicStep.changeset(%{"page_path" => "/blog", "scroll_threshold" => "90"})
        assert changeset.valid?
        assert %DynamicStep{} == changeset.data
        assert get_change(changeset, :page_path) == "/blog"
        assert get_change(changeset, :scroll_threshold) == 90
        assert is_nil(get_change(changeset, :event_name))
      end

      test "validates the input params" do
        changeset =
          DynamicStep.changeset(%{"event_name" => "CustomEvent", "page_path" => "/blog"})

        refute changeset.valid?
        assert {"cannot co-exist with page_path", _} = changeset.errors[:event_name]

        changeset =
          DynamicStep.changeset(%{"event_name" => "Purchase", "currency" => "WRONG"})

        refute changeset.valid?
        assert {"is invalid", _} = changeset.errors[:currency]

        changeset =
          DynamicStep.changeset(%{"page_path" => "/blog", "scroll_threshold" => "-100"})

        refute changeset.valid?
        assert {_, _} = changeset.errors[:scroll_threshold]

        changeset =
          DynamicStep.changeset(%{"page_path" => "/blog", "custom_props" => %{"bad" => -1}})

        refute changeset.valid?
        assert {_, _} = changeset.errors[:custom_props]
      end
    end

    describe "as_goal/1" do
      test "converts a dynamic step to a goal" do
        site = new_site()

        {:ok, funnel} =
          Funnels.create(site, "Example funnel", [
            %{"page_path" => "/blog", "scroll_threshold" => 90},
            %{"event_name" => "Signup"},
            %{"page_path" => "/checkout", "custom_props" => %{"lang" => "de"}},
            %{"event_name" => "Purchase", "currency" => "USD"}
          ])

        [s1, s2, s3, s4] = Funnel.steps(funnel)

        assert DynamicStep.as_goal(s1) == %Plausible.Goal{
                 id: 0,
                 display_name: "Visit /blog",
                 event_name: nil,
                 page_path: "/blog",
                 scroll_threshold: 90,
                 custom_props: %{},
                 currency: nil
               }

        assert DynamicStep.as_goal(s2) == %Plausible.Goal{
                 id: 0,
                 display_name: "Signup",
                 event_name: "Signup",
                 page_path: nil,
                 scroll_threshold: -1,
                 custom_props: %{},
                 currency: nil
               }

        assert DynamicStep.as_goal(s3) == %Plausible.Goal{
                 id: 0,
                 display_name: "Visit /checkout",
                 event_name: nil,
                 page_path: "/checkout",
                 scroll_threshold: -1,
                 custom_props: %{"lang" => "de"},
                 currency: nil
               }

        assert DynamicStep.as_goal(s4) == %Plausible.Goal{
                 id: 0,
                 display_name: "Purchase",
                 event_name: "Purchase",
                 page_path: nil,
                 scroll_threshold: -1,
                 custom_props: %{},
                 currency: :USD
               }
      end
    end
  end
end
