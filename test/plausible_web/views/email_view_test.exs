defmodule PlausibleWeb.EmailViewTest do
  use PlausibleWeb.ConnCase, async: true
  alias PlausibleWeb.EmailView

  describe "user salutation" do
    test "picks first name if full name has two parts" do
      user1 = %Plausible.Auth.User{name: "Jane"}
      user2 = %Plausible.Auth.User{name: "Jane Doe"}
      user3 = %Plausible.Auth.User{name: "Jane Alice Doe"}

      assert EmailView.user_salutation(user1) == "Jane"
      assert EmailView.user_salutation(user2) == "Jane"
      assert EmailView.user_salutation(user3) == "Jane"
    end
  end
end
