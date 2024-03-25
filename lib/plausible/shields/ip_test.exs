defmodule Plausible.Shields.IPTest do
  use Plausible.DataCase
  import Plausible.Shields

  setup do
    site = insert(:site)
    {:ok, %{site: site}}
  end

  describe "add_ip_rule/2" do
    test "no input", %{site: site} do
      assert {:error, changeset} = add_ip_rule(site, %{})
      assert changeset.errors == [inet: {"can't be blank", [validation: :required]}]
      refute changeset.valid?
    end

    test "unsupported netmask", %{site: site} do
      assert {:error, changeset} = add_ip_rule(site, %{"inet" => "127.0.0.0/24"})
      assert changeset.errors == [inet: {"netmask unsupported", []}]
      refute changeset.valid?
      assert {:ok, _} = add_ip_rule(site, %{"inet" => "127.0.0.0/32"})
    end

    test "incorrect ip", %{site: site} do
      assert {:error, changeset} = add_ip_rule(site, %{"inet" => "999.999.999.999"})

      assert changeset.errors == [
               inet: {"is invalid", [{:type, EctoNetwork.INET}, {:validation, :cast}]}
             ]

      refute changeset.valid?
    end

    test "non-strict IPs", %{site: site} do
      assert {:error, _} = add_ip_rule(site, %{"inet" => "111"})
    end

    test "double insert", %{site: site} do
      assert {:ok, _} = add_ip_rule(site, %{"inet" => "0.0.0.111"})
      assert {:error, changeset} = add_ip_rule(site, %{"inet" => "0.0.0.111"})
      refute changeset.valid?

      assert changeset.errors == [
               inet:
                 {"has already been taken",
                  [
                    {:constraint, :unique},
                    {:constraint_name, "shield_rules_ip_site_id_inet_index"}
                  ]}
             ]
    end

    test "ipv6", %{site: site} do
      assert {:ok, rule} =
               add_ip_rule(site, %{"inet" => "2001:0000:130F:0000:0000:09C0:876A:130B"})

      assert ^rule = Repo.get(Plausible.Shield.IPRule, rule.id)
    end

    test "ipv4", %{site: site} do
      assert {:ok, rule} =
               add_ip_rule(site, %{"inet" => "1.1.1.1"})

      assert ^rule = Repo.get(Plausible.Shield.IPRule, rule.id)
    end

    test "over limit", %{site: site} do
      for i <- 1..maximum_ip_rules() do
        assert {:ok, _} =
                 add_ip_rule(site, %{"inet" => "1.1.1.#{i}"})
      end

      assert count_ip_rules(site) == maximum_ip_rules()

      assert {:error, changeset} =
               add_ip_rule(site, %{"inet" => "1.1.1.31"})

      refute changeset.valid?
      assert changeset.errors == [inet: {"maximum reached", []}]
    end

    test "with added_by", %{site: site} do
      assert {:ok, rule} =
               add_ip_rule(site, %{"inet" => "1.1.1.1"},
                 added_by: build(:user, name: "Joe", email: "joe@example.com")
               )

      assert rule.added_by == "Joe <joe@example.com>"
    end
  end

  describe "remove_ip_rule/2" do
    test "is idempontent", %{site: site} do
      {:ok, rule} = add_ip_rule(site, %{"inet" => "127.0.0.1"})
      assert remove_ip_rule(site, rule.id) == :ok
      refute Repo.get(Plausible.Shield.IPRule, rule.id)
      assert remove_ip_rule(site, rule.id) == :ok
    end
  end

  describe "list_ip_rules/1" do
    test "empty", %{site: site} do
      assert(list_ip_rules(site) == [])
    end

    @tag :slow
    test "many", %{site: site} do
      {:ok, r1} = add_ip_rule(site, %{"inet" => "127.0.0.1"})
      :timer.sleep(1000)
      {:ok, r2} = add_ip_rule(site, %{"inet" => "127.0.0.2"})
      assert [^r2, ^r1] = list_ip_rules(site)
    end
  end

  describe "count_ip_rules/1" do
    test "counts", %{site: site} do
      assert count_ip_rules(site) == 0
      {:ok, _} = add_ip_rule(site, %{"inet" => "127.0.0.1"})
      assert count_ip_rules(site) == 1
      {:ok, _} = add_ip_rule(site, %{"inet" => "127.0.0.2"})
      assert count_ip_rules(site) == 2
    end
  end

  describe "IP Rules" do
    test "end to end", %{site: site} do
      site2 = insert(:site)

      assert count_ip_rules(site.id) == 0
      assert list_ip_rules(site.id) == []

      assert {:ok, rule} =
               add_ip_rule(site.id, %{"inet" => "127.0.0.1", "description" => "Localhost"})

      add_ip_rule(site2, %{"inet" => "127.0.0.1", "description" => "Localhost"})

      assert count_ip_rules(site) == 1
      assert [^rule] = list_ip_rules(site)
      assert rule.inet == %Postgrex.INET{address: {127, 0, 0, 1}, netmask: 32}
      assert rule.description == "Localhost"
      assert rule.action == :deny
      refute rule.from_cache?
      assert ip_blocked?(site, "127.0.0.1")
      refute ip_blocked?(site, "127.0.0.2")
    end
  end
end
