# Plausible Insights

Plausible is a simple, lightweight web analytics service that provides the most
important traffic stats without intruding on your visitors' privacy. It collects
unique visitors, referrers, top pages, countries, and device information using a
lightweight script.

![](https://i.ibb.co/wzWYMYb/screenshot.png)

[View live demo of our own analytics](https://plausible.io/plausible.io)

### Why Plausible?

- **Clutter Free**: Stop digging through complex reports to find what you’re looking for. Plausible presents the most important information to you on a single page.
- **Anonymous**: Measure traffic, not individuals. No personal data or IP addresses are ever stored in our database. [Read more about our data policy](https://plausible.io/data-policy)
- **Lightweight**: Plausible works by loading a script on your website, like Google Analytics. Our script is 14x smaller, making your website quicker to load.
- **Email reports**: Keep an eye on your traffic with a weekly email report including pageviews, visitor numbers, top pages and top referrers for the week.
- **Search keywords**: Integrate your dashboard with Google Search Console to get the most accurate reporting on your search keywords.
- **SPA support**: Plausible is built with modern web frameworks in mind and it works automatically with any pushState based router on the frontend.

Interested? [Read more on our website](https://plausible.io)

### Can Plausible be self-hosted?

At the moment we don't provide support for easily self-hosting the code. Currently, the purpose of
keeping the code open-source is to be transparent with the community about how we
collect and process data.

### Technology

Plausible is a standard Elixir/Phoenix application backed by a PostgreSQL database. On the frontend we use
[TailwindCSS](https://tailwindcss.com/) for styling and some vanilla Javascript for interactive bits.

### Feedback & Roadmap

We have a [feedback board](https://feedback.plausible.io/) and a [public roadmap](https://feedback.plausible.io/roadmap).
Please let us know if you have any requests and vote on open issues so we can better prioritize.

### License

Plausible is open-source under the most permissive MIT license. There are no restrictions on redistributing,
modifying or using this software for any reason.
