# Plausible Analytics

[Plausible Analytics](https://plausible.io/) is a simple, lightweight (< 1 KB), open-source and privacy-friendly alternative to Google Analytics. It doesn’t use cookies and is fully compliant with GDPR, CCPA and PECR. You can self-host Plausible or have us run it for you in the Cloud. Here's [the live demo of our own website stats](https://plausible.io/plausible.io). Made and hosted in the EU 🇪🇺

We are dedicated to making web analytics more privacy-friendly. Our mission is to reduce corporate surveillance by providing an alternative web analytics tool which doesn’t come from the AdTech world. The full-time team consists of Uku Taht and Marko Saric. We are completely independent, self-funded and bootstrapped.

![](https://docs.plausible.io/img/plausible-analytics.png)

### Why Plausible?

Here's what makes Plausible a great Google Analytics alternative and why we're trusted by 4,000+ paying subscribers to deliver their website and business insights:

- **Clutter Free**: Plausible Analytics provides [simple web analytics](https://plausible.io/simple-web-analytics) and it cuts through the noise. No layers of menus, no need for custom reports. Get all the important insights on one single page. No training necessary.
- **GDPR/CCPA/PECR compliant**: Measure traffic, not individuals. No personal data or IP addresses are ever stored in our database. We don't use cookies or any other persistent idenfitiers. [Read more about our data policy](https://plausible.io/data-policy)
- **Lightweight**: Plausible Analytics works by loading a script on your website, like Google Analytics. Our script is [45x smaller](https://plausible.io/lightweight-web-analytics), making your website quicker to load.
- **Email or Slack reports**: Keep an eye on your traffic with weekly and/or monthly email or Slack reports. You can also get traffic spike notifications.
- **Open website stats**: You have the option to be transparent and open your web analytics to everyone. Your website stats are private by default but you can choose to make them public so anyone with your custom link can view them.
- **Define key goals and track conversions**: Set custom events or page URLs as your goals and see how they convert over time to understand and identify the trends that matter. Includes easy ways to track outbound link clicks and 404 error pages.
- **Search keywords**: Integrate your dashboard with Google Search Console to get the most accurate reporting on your search keywords.
- **SPA support**: Plausible is built with modern web frameworks in mind and it works automatically with any pushState based router on the frontend. We also support frameworks that use the URL hash for routing. See [our documentation](https://plausible.io/docs/hash-based-routing).

Interested to learn more? [Read more on our website](https://plausible.io), learn more about the team and the goals of the project on [our about page](https://plausible.io/about) or explore [the documentation](https://plausible.io/docs).

### Why is Plausible Analytics Cloud not free like Google Analytics?

Plausible Analytics is an independently owned and actively developed project. To keep the project development going, to stay in business, to continue putting effort into building a better product and to cover our costs, we need to charge a fee.

Google Analytics is free because Google has built their company and their wealth by collecting and analyzing huge amounts of personal information from web users and using these personal and behavioral insights to sell advertisements.

Plausible has no part in that business model. No personal data is being collected and analyzed either. With Plausible, you 100% own and control all of your website data. This data is not being shared with or sold to any third-parties.

We choose the subscription business model rather than the business model of surveillance capitalism. See reasons why we believe you should [stop using Google Analytics on your website](https://plausible.io/blog/remove-google-analytics).

### Can Plausible Analytics be self-hosted?

Yes, Plausible is fully [open source web analytics](https://plausible.io/open-source-website-analytics).

We have a free as in beer [Plausible Analytics Self-Hosted](https://plausible.io/self-hosted-web-analytics) solution. It’s exactly the same product as our Cloud solution with a less frequent release schedule (think of it as a long term support release).

Bug fixes and new features are released to the cloud version several times per week. Features are battle-tested in the cloud which allows us to fix any bugs before the general self-hosted release. Every six months we combine all the changes into a new self-hosted release.

The main difference between the two is that the self-hosted version you have to install, host and manage yourself on your own infrastructure while the Cloud version we manage everything for your ease and convenience. Here's the overview of all the differences:

|  | Cloud  | Self-hosted |
| ------------- | ------------- | ------------- |
| Hosting | Easy and convenient. We manage everything for you so you don’t have to worry about anything. We take care of the installation, upgrades, server, security, maintenance, uptime, stability, consistency, loading time and so on.  | You do it all yourself. You need to get a server and you need to install, maintain and manage Plausible on that server. You are responsible for installation, maintenance, upgrades, server capacity, uptime, backup and so on.  |
| Storage | We keep your site data on a secure, encrypted and green energy powered server in Germany. A server that ensures that your site data is protected by the strict European Union data privacy laws.  | You have full control and can host your Plausible Analytics on any server in any country that you wish. Host it on a server in your basement or host it with any cloud provider wherever you want.  |
| Raw data | You see all your site stats and metrics on our modern-looking, simple to use and fast loading dashboard. You can only see the stats aggregated in the dashboard.  | Are you an analyst and want access to the raw data? Hosting Plausible yourself gives you that option. Take the data directly from the ClickHouse database and import it to a data analysis tool of your choice.  |
| Costs | There’s a cost associated with providing an analytics service so we charge a subscription fee. We choose the subscription business model rather than the business model of surveillance capitalism.  | You only need to pay for your server and whatever cost there is associated with running a server. You never have to pay any fees to us, only to your cloud provider.  |
| Releases | Continuously developed and improved with new features and frequent updates.  | [It’s a long term release](https://plausible.io/blog/building-open-source) so latest features won’t be immediately available as they’re battled-tested in the cloud before released to self-hosted.  |

Interested in self-hosting Plausible on your server? Take a look at our [self-hosting installation instructions](https://plausible.io/docs/self-hosting).

Plausible Self-Hosted is a community supported project and there are no guarantees that you will get support from the creators of Plausible to troubleshoot your self-hosting issues. There is a [community supported forum](https://github.com/plausible/analytics/discussions/categories/self-hosted-support) where you can ask for help.

If you choose to self-host Plausible you can [become a sponsor](https://github.com/sponsors/plausible) which is a great way to give back to the community and to contribute to the long-term sustainability of the project. Simply put, we treat sponsors like paying customers which means you can receive guaranteed priority support.

### Technology

Plausible Analytics is a standard Elixir/Phoenix application backed by a PostgreSQL database for general data and a Clickhouse
database for stats. On the frontend we use [TailwindCSS](https://tailwindcss.com/) for styling and React to make the dashboard interactive.

### Feedback & Roadmap

We welcome feedback from our community. We have a public roadmap driven by the features suggested by the community members. Take a look at our [feedback board](https://plausible.io/feedback) and our [public roadmap](https://plausible.io/roadmap) directly here on GitHub. Please let us know if you have any requests and vote on open issues so we can better prioritize.

### License

Plausible is open-source under the GNU Affero General Public License Version 3 (AGPLv3) or any later version. You can [find it here](https://github.com/plausible/analytics/blob/master/LICENSE.md).

The only exception is our javascript tracker which gets included on your website. To avoid issues with AGPL virality, we've
released the tracker under the MIT license. You can [find it here](https://github.com/plausible/analytics/blob/master/tracker/LICENSE.md).
