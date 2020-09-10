# Plausible Analytics

[![Build Status](https://travis-ci.org/plausible/analytics.svg?branch=master)](https://travis-ci.org/plausible/analytics)

[Plausible Analytics](https://plausible.io/) is a simple, lightweight (< 1 KB), open-source and privacy-friendly alternative to Google Analytics. It doesn’t use cookies and is fully compliant with GDPR, CCPA and PECR. You can self-host Plausible or have us run it for you in the Cloud. Here's [the live demo of our own website stats](https://plausible.io/plausible.io). We are completely independent, self-funded and bootstrapped. Made and hosted in the EU 🇪🇺

![](https://docs.plausible.io/img/plausible-analytics.png)

### Why Plausible?

- **Clutter Free**: Plausible Analytics provides [simple web analytics](https://plausible.io/simple-web-analytics) and it cuts through the noise. No layers of menus, no need for custom reports. Get all the important insights on one single page. No training necessary.
- **GDPR/CCPA/PECR compliant**: Measure traffic, not individuals. No personal data or IP addresses are ever stored in our database. We don't use cookies either. [Read more about our data policy](https://plausible.io/data-policy)
- **Lightweight**: Plausible Analytics works by loading a script on your website, like Google Analytics. Our script is [45x smaller](https://plausible.io/lightweight-web-analytics), making your website quicker to load.
- **Email reports**: Keep an eye on your traffic with weekly and/or monthly email reports. All the stats are embedded directly in the email and there’s no need to go to any website. No attachments, no PDFs and no links to click on.
- **Open website stats**: You have the option to be transparent and open your web analytics to everyone. Your website stats are private by default but you can choose to make them public so anyone with your custom link can view them.
- **Define key goals and track conversions**: Set custom events or page URLs as your goals and see how they convert over time to understand and identify the trends that matter.
- **Search keywords**: Integrate your dashboard with Google Search Console to get the most accurate reporting on your search keywords.
- **SPA support**: Plausible is built with modern web frameworks in mind and it works automatically with any pushState based router on the frontend. We also support frameworks that use the URL hash for routing. See [our documentation](https://docs.plausible.io/hash-based-routing).

Interested to learn more? [Read more on our website](https://plausible.io), learn more about the team and the goals of the project on [our about page](https://plausible.io/about) or explore [the documentation](https://docs.plausible.io).

### Can Plausible Analytics be self-hosted?

Yes, Plausible is fully [open source web analytics](https://plausible.io/open-source-website-analytics). We have a free as in beer Plausible Analytics Self-Hosted solution. It’s exactly the same product as our Cloud solution, only the self-hosted version you have to install, host and manage yourself on your own server. Take a look at our [docker-based self hosting](./HOSTING.md) setup. Please note that this is still in *beta* stage and care should be taken while using it for production system.

### Why is Plausible Analytics Cloud not free like Google Analytics?

Plausible Analytics is an independently owned and actively developed project. To keep the project development going, to stay in business, to continue putting effort into building a better product and to cover our costs, we need to charge a fee.

Google Analytics is free because Google has built their company and their wealth by collecting and analyzing huge amounts of personal information from web users and using these personal and behavioral insights to sell advertisements.

Plausible has no part in that business model. No personal data is being collected and analyzed either. With Plausible, you 100% own and control all of your website data. This data is not being shared with or sold to any third-parties.

We choose the subscription business model rather than the business model of surveillance capitalism. See reasons why we believe you should [stop using Google Analytics on your website](https://plausible.io/blog/remove-google-analytics).

### Technology

Plausible Analytics is a standard Elixir/Phoenix application backed by a PostgreSQL database for general data and a Clickhouse
database for stats. On the frontend we use [TailwindCSS](https://tailwindcss.com/) for styling and React to make the dashboard interactive.

### Feedback & Roadmap

We welcome feedback from our community. We have a public roadmap driven by the features suggested by the community members. Take a look at our [feedback board](https://plausible.io/feedback) and our [public roadmap](https://plausible.io/roadmap) directly here on GitHub. Please let us know if you have any requests and vote on open issues so we can better prioritize.

### License

Plausible is open-source under the most permissive Massachusetts Institute of Technology (MIT) license. This means that there are no restrictions on redistributing, modifying or using Plausible software for any reason. You can take it and use it any way that you wish.
