# Plausible Analytics

<p align="center">
  <a href="https://plausible.io/">
    <img src="https://raw.githubusercontent.com/plausible/docs/master/static/img/plausible-analytics-icon-top.png" width="140px" alt="Plausible Analytics" />
  </a>
</p>
<p align="center">
    <a href="https://plausible.io/simple-web-analytics">Simple Metrics</a> |
    <a href="https://plausible.io/lightweight-web-analytics">Lightweight Script</a> |
    <a href="https://plausible.io/privacy-focused-web-analytics">Privacy Focused</a> |
    <a href="https://plausible.io/open-source-website-analytics">Open Source</a> |
    <a href="https://plausible.io/docs">Docs</a> |
    <a href="https://github.com/plausible/analytics/blob/master/CONTRIBUTING.md">Contributing</a>
    <br /><br />
</p>

[Plausible Analytics](https://plausible.io/) is an easy to use, lightweight, open source and privacy-friendly alternative to Google Analytics. It doesn’t use cookies and is fully compliant with GDPR, CCPA and PECR. You can self-host Plausible Community Edition or have us manage Plausible Analytics for you in the cloud. Here's [the live demo of our own website stats](https://plausible.io/plausible.io). Made and hosted in the EU 🇪🇺

We are dedicated to making web analytics more privacy-friendly. Our mission is to reduce corporate surveillance by providing an alternative web analytics tool which doesn’t come from the AdTech world. We are completely independent and solely funded by our subscribers.

![Plausible Analytics](https://plausible.io/docs/img/plausible-analytics.png)

## Why Plausible?

Here's what makes Plausible a great Google Analytics alternative and why we're trusted by thousands of paying subscribers to deliver their website and business insights:

- **Clutter Free**: Plausible Analytics provides [simple web analytics](https://plausible.io/simple-web-analytics) and it cuts through the noise. No layers of menus, no need for custom reports. Get all the important insights on one single page. No training necessary.
- **GDPR/CCPA/PECR compliant**: Measure traffic, not individuals. No personal data or IP addresses are ever stored in our database. We don't use cookies or any other persistent identifiers. [Read more about our data policy](https://plausible.io/data-policy)
- **Lightweight**: Plausible Analytics works by loading a script on your website, like Google Analytics. Our script is [small](https://plausible.io/lightweight-web-analytics), making your website quicker to load. You can also send events directly to our [events API](https://plausible.io/docs/events-api).
- **Email or Slack reports**: Keep an eye on your traffic with weekly and/or monthly email or Slack reports. You can also get traffic spike notifications.
- **Invite team members and share stats**: You have the option to be transparent and open your web analytics to everyone. Your website stats are private by default but you can choose to make them public so anyone with your custom link can view them. You can [invite team members](https://plausible.io/docs/users-roles) and assign user roles too.
- **Define key goals and track conversions**: Create custom events with custom dimensions to track conversions and attribution to understand and identify the trends that matter. Track ecommerce revenue, outbound link clicks, file downloads and 404 error pages. Increase conversions using funnel analysis.
- **Search keywords**: Integrate your dashboard with Google Search Console to get the most accurate reporting on your search keywords.
- **SPA support**: Plausible is built with modern web frameworks in mind and it works automatically with any pushState based router on the frontend. We also support frameworks that use the URL hash for routing. See [our documentation](https://plausible.io/docs/hash-based-routing).
- **Smooth transition from Google Analytics**: There's a realtime dashboard, entry pages report and integration with Search Console. You can track your paid campaigns and conversions. You can invite team members. You can even [import your historical Google Analytics stats](https://plausible.io/docs/google-analytics-import). Learn how to [get the most out of your Plausible experience](https://plausible.io/docs/your-plausible-experience) and join thousands who have already migrated from Google Analytics.

Interested to learn more? [Read more on our website](https://plausible.io), learn more about the team and the goals of the project on [our about page](https://plausible.io/about) or explore [the documentation](https://plausible.io/docs).

## Why is Plausible Analytics Cloud not free like Google Analytics?

Plausible Analytics is an independently owned and actively developed project. To keep the project development going, to stay in business, to continue putting effort into building a better product and to cover our costs, we need to charge a fee.

Google Analytics is free because Google has built their company and their wealth by collecting and analyzing huge amounts of personal information from web users and using these personal and behavioral insights to sell advertisements.

Plausible has no part in that business model. No personal data is being collected and analyzed either. With Plausible, you 100% own and control all of your website data. This data is not being shared with or sold to any third-parties.

We choose the subscription business model rather than the business model of surveillance capitalism. See reasons why we believe you should [stop using Google Analytics on your website](https://plausible.io/blog/remove-google-analytics).

## Getting started with Plausible

The easiest way to get started with Plausible Analytics is with [our official managed service in the cloud](https://plausible.io/#pricing). It takes 2 minutes to start counting your stats with a worldwide CDN, high availability, backups, security and maintenance all done for you by us.

In order to be compliant with the GDPR and the Schrems II ruling, all visitor data for our managed service in the cloud is exclusively processed on servers and cloud infrastructure owned and operated by European providers. Your website data never leaves the EU.

Our managed hosting can save a substantial amount of developer time and resources. For most sites this ends up being the best value option and the revenue goes to funding the maintenance and further development of Plausible. So you’ll be supporting open source software and getting a great service!

### Can Plausible be self-hosted?

Plausible is [open source web analytics](https://plausible.io/open-source-website-analytics) and we have a free as in beer and self-hosted solution called [Plausible Community Edition (CE)](https://plausible.io/self-hosted-web-analytics). Here are the differences between Plausible Analytics managed hosting in the cloud and the Plausible CE:

|  | Plausible Analytics Cloud  | Plausible Community Edition |
| ------------- | ------------- | ------------- |
| **Infrastructure management** | Easy and convenient. It takes 2 minutes to start counting your stats with a worldwide CDN, high availability, backups, security and maintenance all done for you by us. We manage everything so you don’t have to worry about anything and can focus on your stats. | You do it all yourself. You need to get a server and you need to manage your infrastructure. You are responsible for installation, maintenance, upgrades, server capacity, uptime, backup, security, stability, consistency, loading time and so on.|
| **Release schedule** | Continuously developed and improved with new features and updates multiple times per week. | [It's a long term release](https://plausible.io/blog/building-open-source) published twice per year so latest features and improvements won't be immediately available.|
| **Premium features** | All features available as listed in [our pricing plans](https://plausible.io/#pricing). | Premium features (marketing funnels, ecommerce revenue goals and sites API) are not available in order to help support [the project's long-term sustainability](https://plausible.io/blog/community-edition).|
| **Bot filtering** | Advanced bot filtering for more accurate stats. Our algorithm detects and excludes non-human traffic patterns. We also exclude known bots by the User-Agent header and filter out traffic from data centers and referrer spam domains. We exclude ~32K data center IP ranges (i.e. a lot of bot IP addresses) by default. | Basic bot filtering that targets the most common non-human traffic based on the User-Agent header and referrer spam domains.|
| **Server location** | All visitor data is exclusively processed on EU-owned cloud infrastructure. We keep your site data on a secure, encrypted and green energy powered server in Germany. This ensures that your site data is protected by the strict European Union data privacy laws and ensures compliance with GDPR. Your website data never leaves the EU. | You have full control and can host your instance on any server in any country that you wish. Host it on a server in your basement or host it with any cloud provider wherever you want, even those that are not GDPR compliant.|
| **Data portability** | You see all your site stats and metrics on our modern-looking, simple to use and fast loading dashboard. You can only see the stats aggregated in the dashboard. You can download the stats using the [CSV export](https://plausible.io/docs/export-stats), [stats API](https://plausible.io/docs/stats-api) or tools such as the [Data Studio Connector](https://plausible.io/docs/integration-guides#google-data-studio). | Do you want access to the raw data? Self-hosting gives you that option. You can take the data directly from the ClickHouse database. |
| **Premium support** | Real support delivered by real human beings who build and maintain Plausible. | Premium support is not included. CE is community supported only.|
| **Costs** | There's a cost associated with providing an analytics service so we charge a subscription fee. We choose the subscription business model rather than the business model of surveillance capitalism. Your money funds further development of Plausible. | You need to pay for your server, CDN, backups and whatever other cost there is associated with running the infrastructure. You never have to pay any fees to us. Your money goes to 3rd party companies with no connection to us.|

Interested in self-hosting Plausible CE on your server? Take a look at our [Plausible CE installation instructions](https://github.com/plausible/community-edition/).

Plausible CE is a community supported project and there are no guarantees that you will get support from the creators of Plausible to troubleshoot your self-hosting issues. There is a [community supported forum](https://github.com/plausible/analytics/discussions/categories/self-hosted-support) where you can ask for help.

Our only source of funding is our premium, managed service for running Plausible in the cloud.
 
## Technology

Plausible Analytics is a standard Elixir/Phoenix application backed by a PostgreSQL database for general data and a Clickhouse
database for stats. On the frontend we use [TailwindCSS](https://tailwindcss.com/) for styling and React to make the dashboard interactive.

## Contributors

For anyone wishing to contribute to Plausible, we recommend taking a look at [our contributor guide](https://github.com/plausible/analytics/blob/master/CONTRIBUTING.md).

<a href="https://github.com/plausible/analytics/graphs/contributors"><img src="https://opencollective.com/plausible/contributors.svg?width=800&button=false" /></a>

## Feedback & Roadmap

We welcome feedback from our community. We have a public roadmap driven by the features suggested by the community members. Take a look at our [feedback board](https://plausible.io/feedback). Please let us know if you have any requests and vote on open issues so we can better prioritize.

To stay up to date with all the latest news and product updates, make sure to follow us on [X (formerly Twitter)](https://twitter.com/plausiblehq), [LinkedIn](https://www.linkedin.com/company/plausible-analytics/) or [Mastodon](https://fosstodon.org/@plausible).

## License & Trademarks

Plausible CE is open source under the GNU Affero General Public License Version 3 (AGPLv3) or any later version. You can [find it here](https://github.com/plausible/analytics/blob/master/LICENSE.md).

To avoid issues with AGPL virality, we've released the JavaScript tracker which gets included on your website under the MIT license. You can [find it here](https://github.com/plausible/analytics/blob/master/tracker/LICENSE.md).

Copyright (c) 2018-present Plausible Insights OÜ. Plausible Analytics name and logo are trademarks of Plausible Insights OÜ. Please see our [trademark guidelines](https://plausible.io/trademark) for info on acceptable usage.
