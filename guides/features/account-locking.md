# Account locking
This document explains the account locking feature from a technical perspective. Account locking happens when users have outgrown their accounts, and despite alert, don't upgrade after a grace period.

## Usage alert and grace period
The `Plausible.Workers.CheckUsage` daily background job alerts users they have reached their subscription limits. This runs for outgrown users one day after their last billing date.

When users reach the number of sites limit, or use >110% of their pageview limit for 2 consecutive billing cycles, the background job sends them an e-mail alert. The e-mail suggests a suitable subscription plan based on usage. For enterprise users, an additional internal e-mail is sent to `enterprise@plausible.io`.

The user is given 7 days to upgrade their account after the alert, and this is called grace period. After sending the e-mail, the background job starts the grace period by updating `users.grace_period` JSON field. 

```json
// SELECT grace_period FROM users LIMIT 1

{
  "id": "1aa855bd-022d-4dfc-b572-6853442c3f19",
  "is_over": true,
  "end_date": "2022-03-09",
  "allowance_required": 100
}
```


During this period, the following alert pops up on the dashboard:

![](https://files.gitbook.com/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FN4GLWMwCrTuTcf31kYE9%2Fuploads%2FmsLk4CdSHKzU8TbfvaPq%2FPasted%20image%2020220909120933.png?alt=media&token=76f247a1-28cf-4d88-a0fa-06547268aee9)

If the user upgrades to a suitable plan, the grace period is removed (check `Plausible.Billing.subscription_updated/1`), otherwise [[#Account locking]] follows.

## Account locking
The grace period is checked daily by the `Plausible.Workers.LockSites` background job.

For users that expired their grace period, `sites.locked` is is set to `true`, restricting access to dashboards. This does not stop event ingestion, so users can have their stats up to date when they finally upgrade.

![](https://files.gitbook.com/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FN4GLWMwCrTuTcf31kYE9%2Fuploads%2FAplurtG7UsGXMskZOlUO%2FPasted%20image%2020220909122622.png?alt=media&token=5c8156d7-d4a7-4c99-8bac-2f1e9b7d4cae)
