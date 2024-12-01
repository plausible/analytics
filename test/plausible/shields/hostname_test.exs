defmodule Plausible.Shields.HostnameTest do
  use Plausible.DataCase
  import Plausible.Shields

  setup do
    site = insert(:site)
    {:ok, %{site: site}}
  end

  describe "add_hostname_rule/2" do
    test "no input", %{site: site} do
      assert {:error, changeset} = add_hostname_rule(site, %{})
      assert changeset.errors == [hostname: {"can't be blank", [validation: :required]}]
      refute changeset.valid?
    end

    test "lengthy", %{site: site} do
      long = "/" <> :binary.copy("a", 251)
      assert {:error, changeset} = add_hostname_rule(site, %{"hostname" => long})
      assert [hostname: {"should be at most %{count} character(s)", _}] = changeset.errors
      refute changeset.valid?
    end

    test "double insert", %{site: site} do
      assert {:ok, _} = add_hostname_rule(site, %{"hostname" => "/test"})
      assert {:error, changeset} = add_hostname_rule(site, %{"hostname" => "/test"})
      refute changeset.valid?

      assert changeset.errors == [
               hostname:
                 {"rule already exists",
                  [
                    {:constraint, :unique},
                    {:constraint_name, "shield_rules_hostname_site_id_hostname_pattern_index"}
                  ]}
             ]
    end

    test "equivalent rules are counted as dupes", %{site: site} do
      assert {:ok, _} = add_hostname_rule(site, %{"hostname" => "test*"})
      assert {:error, changeset} = add_hostname_rule(site, %{"hostname" => "test**"})

      assert changeset.errors == [
               hostname:
                 {"rule already exists",
                  [
                    {:constraint, :unique},
                    {:constraint_name, "shield_rules_hostname_site_id_hostname_pattern_index"}
                  ]}
             ]
    end

    test "regex storage: wildcard", %{site: site} do
      assert {:ok, rule} = add_hostname_rule(site, %{"hostname" => "*test"})
      assert rule.hostname_pattern == "^.*test$"
    end

    test "regex storage: no wildcard", %{site: site} do
      assert {:ok, rule} = add_hostname_rule(site, %{"hostname" => "test"})
      assert rule.hostname_pattern == "^test$"
    end

    test "regex storage: escaping", %{site: site} do
      assert {:ok, rule} = add_hostname_rule(site, %{"hostname" => "test.*.**.|+[0-9]"})
      assert rule.hostname_pattern == "^test\\..*\\..*\\.\\|\\+\\[0\\-9\\]$"
    end

    test "over limit", %{site: site} do
      for i <- 1..maximum_hostname_rules() do
        assert {:ok, _} =
                 add_hostname_rule(site, %{"hostname" => "test-#{i}"})
      end

      assert count_hostname_rules(site) == maximum_hostname_rules()

      assert {:error, changeset} =
               add_hostname_rule(site, %{"hostname" => "test.limit"})

      refute changeset.valid?
      assert changeset.errors == [hostname: {"maximum reached", []}]
    end

    test "with added_by", %{site: site} do
      assert {:ok, rule} =
               add_hostname_rule(site, %{"hostname" => "test.example.com"},
                 added_by: build(:user, name: "Joe", email: "joe@example.com")
               )

      assert rule.added_by == "Joe <joe@example.com>"
    end
  end

  describe "hostname pattern matching" do
    test "no wildcard", %{site: site} do
      assert {:ok, _} = add_hostname_rule(site, %{"hostname" => "test.example.com"})
      assert hostname_allowed?(site, "test.example.com")
      refute hostname_allowed?(site, "subdmoain.example.com")
      refute hostname_allowed?(site, "test")
    end

    test "wildcard - subdomains", %{site: site} do
      assert {:ok, _} = add_hostname_rule(site, %{"hostname" => "*.example.com"})
      refute hostname_allowed?(site, "example.com")
      refute hostname_allowed?(site, "example.com.pl")
      assert hostname_allowed?(site, "subdomain.example.com")
    end

    test "wildcard - any prefix", %{site: site} do
      assert {:ok, _} = add_hostname_rule(site, %{"hostname" => "*example.com"})
      assert hostname_allowed?(site, "example.com")
      refute hostname_allowed?(site, "example.com.pl")
      assert hostname_allowed?(site, "subdomain.example.com")
    end
  end

  describe "remove_hostname_rule/2" do
    test "is idempotent", %{site: site} do
      {:ok, rule} = add_hostname_rule(site, %{"hostname" => "test"})
      assert remove_hostname_rule(site, rule.id) == :ok
      refute Repo.get(Plausible.Shield.HostnameRule, rule.id)
      assert remove_hostname_rule(site, rule.id) == :ok
    end
  end

  describe "list_hostname_rules/1" do
    test "empty", %{site: site} do
      assert(list_hostname_rules(site) == [])
    end

    @tag :slow
    test "many", %{site: site} do
      {:ok, %{id: id1}} = add_hostname_rule(site, %{"hostname" => "test1.example.com"})
      :timer.sleep(1000)
      {:ok, %{id: id2}} = add_hostname_rule(site, %{"hostname" => "test2.example.com"})
      assert [%{id: ^id2}, %{id: ^id1}] = list_hostname_rules(site)
    end
  end

  describe "count_hostname_rules/1" do
    test "counts", %{site: site} do
      assert count_hostname_rules(site) == 0
      {:ok, _} = add_hostname_rule(site, %{"hostname" => "test1"})
      assert count_hostname_rules(site) == 1
      {:ok, _} = add_hostname_rule(site, %{"hostname" => "test2"})
      assert count_hostname_rules(site) == 2
    end
  end

  describe "allowed_hostname_patterns/1" do
    test "returns a list of regular expressions when rules are defined", %{site: site} do
      {:ok, _} = add_hostname_rule(site, %{"hostname" => "example.com"})
      {:ok, _} = add_hostname_rule(site, %{"hostname" => "another.example.com"})
      {:ok, _} = add_hostname_rule(site, %{"hostname" => "app.*"})

      allowed = allowed_hostname_patterns(site.domain)

      assert length(allowed) == 3
      assert "^example\\.com$" in allowed
      assert "^another\\.example\\.com$" in allowed
      assert "^app\\..*$" in allowed
    end
  end

  describe "Hostname Rules" do
    test "end to end", %{site: site} do
      site2 = insert(:site)

      assert count_hostname_rules(site.id) == 0
      assert list_hostname_rules(site.id) == []

      assert {:ok, rule} =
               add_hostname_rule(site.id, %{
                 "hostname" => "blog.example.com"
               })

      add_hostname_rule(site2, %{"hostname" => "portral.example.com"})

      assert count_hostname_rules(site) == 1
      assert [%{id: rule_id}] = list_hostname_rules(site)
      assert rule.id == rule_id
      assert rule.hostname == "blog.example.com"
      assert rule.action == :allow
      refute rule.from_cache?
      assert hostname_allowed?(site, "blog.example.com")
      refute hostname_allowed?(site, "portal.example.com")
    end
  end
end
