use Plausible

import Plausible.Teams.Test

hours_ago = fn hr ->
  NaiveDateTime.utc_now(:second) |> NaiveDateTime.add(-hr, :hour)
end

user = new_user(email: "user@plausible.test", password: "plausible")

public_site = new_site(domain: "public.example.com", public: true)

Plausible.TestUtils.populate_stats(public_site, [
  Plausible.Factory.build(:pageview, pathname: "/page1", timestamp: hours_ago.(48)),
  Plausible.Factory.build(:pageview, pathname: "/page2", timestamp: hours_ago.(48)),
  Plausible.Factory.build(:pageview, pathname: "/page3", timestamp: hours_ago.(48)),
  Plausible.Factory.build(:pageview, pathname: "/other", timestamp: hours_ago.(48))
])

private_site = new_site(domain: "private.example.com", owner: user)

Plausible.TestUtils.populate_stats(private_site, [
  Plausible.Factory.build(:pageview, pathname: "/", timestamp: hours_ago.(48))
])
