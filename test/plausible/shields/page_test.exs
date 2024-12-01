defmodule Plausible.Shields.PageTest do
  use Plausible.DataCase
  import Plausible.Shields

  setup do
    site = insert(:site)
    {:ok, %{site: site}}
  end

  describe "add_page_rule/2" do
    test "no input", %{site: site} do
      assert {:error, changeset} = add_page_rule(site, %{})
      assert changeset.errors == [page_path: {"can't be blank", [validation: :required]}]
      refute changeset.valid?
    end

    test "no slash", %{site: site} do
      assert {:error, changeset} = add_page_rule(site, %{"page_path" => "test"})
      assert changeset.errors == [page_path: {"must start with /", []}]
      refute changeset.valid?
    end

    test "lengthy", %{site: site} do
      long = "/" <> :binary.copy("a", 251)
      assert {:error, changeset} = add_page_rule(site, %{"page_path" => long})
      assert [page_path: {"should be at most %{count} character(s)", _}] = changeset.errors
      refute changeset.valid?
    end

    test "double insert", %{site: site} do
      assert {:ok, _} = add_page_rule(site, %{"page_path" => "/test"})
      assert {:error, changeset} = add_page_rule(site, %{"page_path" => "/test"})
      refute changeset.valid?

      assert changeset.errors == [
               page_path:
                 {"rule already exists",
                  [
                    {:constraint, :unique},
                    {:constraint_name, "shield_rules_page_site_id_page_path_pattern_index"}
                  ]}
             ]
    end

    test "equivalent rules are counted as dupes", %{site: site} do
      assert {:ok, _} = add_page_rule(site, %{"page_path" => "/test/*"})
      assert {:error, changeset} = add_page_rule(site, %{"page_path" => "/test/**"})

      assert changeset.errors == [
               page_path:
                 {"rule already exists",
                  [
                    {:constraint, :unique},
                    {:constraint_name, "shield_rules_page_site_id_page_path_pattern_index"}
                  ]}
             ]
    end

    test "regex storage: wildcard", %{site: site} do
      assert {:ok, rule} = add_page_rule(site, %{"page_path" => "/test/*"})
      assert rule.page_path_pattern == "^/test/.*$"
    end

    test "regex storage: no wildcard", %{site: site} do
      assert {:ok, rule} = add_page_rule(site, %{"page_path" => "/test"})
      assert rule.page_path_pattern == "^/test$"
    end

    test "regex storage: escaping", %{site: site} do
      assert {:ok, rule} = add_page_rule(site, %{"page_path" => "/test/*/**/|+[0-9]"})
      assert rule.page_path_pattern == "^/test/.*/.*/\\|\\+\\[0\\-9\\]$"
    end

    test "over limit", %{site: site} do
      for i <- 1..maximum_page_rules() do
        assert {:ok, _} =
                 add_page_rule(site, %{"page_path" => "/test/#{i}"})
      end

      assert count_page_rules(site) == maximum_page_rules()

      assert {:error, changeset} =
               add_page_rule(site, %{"page_path" => "/test/31"})

      refute changeset.valid?
      assert changeset.errors == [page_path: {"maximum reached", []}]
    end

    test "with added_by", %{site: site} do
      assert {:ok, rule} =
               add_page_rule(site, %{"page_path" => "/test"},
                 added_by: build(:user, name: "Joe", email: "joe@example.com")
               )

      assert rule.added_by == "Joe <joe@example.com>"
    end
  end

  describe "page pattern matching" do
    test "no wildcard", %{site: site} do
      assert {:ok, _} = add_page_rule(site, %{"page_path" => "/test"})
      assert page_blocked?(site, "/test")
      refute page_blocked?(site, "/test/hello")
      refute page_blocked?(site, "test")
    end

    test "wildcard", %{site: site} do
      assert {:ok, _} = add_page_rule(site, %{"page_path" => "/test/*"})
      refute page_blocked?(site, "/test")
      assert page_blocked?(site, "/test/")
      assert page_blocked?(site, "/test/hello")
      refute page_blocked?(site, "test")
      refute page_blocked?(site, "/testing")
    end
  end

  describe "remove_page_rule/2" do
    test "is idempotent", %{site: site} do
      {:ok, rule} = add_page_rule(site, %{"page_path" => "/test"})
      assert remove_page_rule(site, rule.id) == :ok
      refute Repo.get(Plausible.Shield.PageRule, rule.id)
      assert remove_page_rule(site, rule.id) == :ok
    end
  end

  describe "list_page_rules/1" do
    test "empty", %{site: site} do
      assert(list_page_rules(site) == [])
    end

    @tag :slow
    test "many", %{site: site} do
      {:ok, %{id: id1}} = add_page_rule(site, %{"page_path" => "/test1"})
      :timer.sleep(1000)
      {:ok, %{id: id2}} = add_page_rule(site, %{"page_path" => "/test2"})
      assert [%{id: ^id2}, %{id: ^id1}] = list_page_rules(site)
    end
  end

  describe "count_page_rules/1" do
    test "counts", %{site: site} do
      assert count_page_rules(site) == 0
      {:ok, _} = add_page_rule(site, %{"page_path" => "/test1"})
      assert count_page_rules(site) == 1
      {:ok, _} = add_page_rule(site, %{"page_path" => "/test2"})
      assert count_page_rules(site) == 2
    end
  end

  describe "Page Rules" do
    test "end to end", %{site: site} do
      site2 = insert(:site)

      assert count_page_rules(site.id) == 0
      assert list_page_rules(site.id) == []

      assert {:ok, rule} =
               add_page_rule(site.id, %{
                 "page_path" => "/test"
               })

      add_page_rule(site2, %{"page_path" => "/test"})

      assert count_page_rules(site) == 1
      assert [%{id: rule_id}] = list_page_rules(site)
      assert rule.id == rule_id
      assert rule.page_path == "/test"
      assert rule.action == :deny
      refute rule.from_cache?
      assert page_blocked?(site, "/test")
      refute page_blocked?(site, "/testing")
    end
  end
end
