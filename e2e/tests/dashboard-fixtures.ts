import type { Page, Request } from "@playwright/test";
import { expect } from "@playwright/test";

type User = {
  name: string;
  email: string;
  password: string;
};

export class AuthPage {
  constructor(
    public readonly page: Page,
    public readonly request: Request,
  ) {}

  async register(user: User) {
    await this.page.goto("/register");

    await expect(this.page.locator(".phx-connected")).toHaveCount(1);

    await expect(
      this.page.getByRole("button", { name: "Start my free trial" }),
    ).toBeVisible();

    await this.page.getByLabel("Full name").fill(user.name);
    await this.page.getByLabel("Email").fill(user.email);
    await this.page.getByLabel("Password", { exact: true }).fill(user.password);
    await this.page
      .getByLabel("Confirm password", { exact: true })
      .fill(user.password);
    await expect(
      this.page.getByRole("button", { name: "Start my free trial" }),
    ).toBeEnabled();
    await this.page
      .getByRole("button", { name: "Start my free trial" })
      .click();

    await expect(
      this.page.getByRole("heading", { name: "Activate your account" }),
    ).toBeVisible();

    const response = await this.request.get("/sent-emails-api/emails.json");

    const emailData = await response.json();

    const emails = emailData.filter(
      (e) =>
        e.to[0][0] === user.name &&
        e.subject.indexOf("is your Plausible email verification code") > -1,
    );

    expect(emails.length).toEqual(1);

    const [code] = emails[0].subject.split(" ");

    await this.page.goto("/activate");

    await this.page.locator("input[name=code]").fill(code);

    await this.page.getByRole("button", { name: "Activate" }).click();

    await expect(
      this.page.getByRole("button", { name: "Install Plausible" }),
    ).toBeVisible();
  }

  async login(user: User) {
    await this.page.goto("/login");

    await expect(
      this.page.getByRole("button", { name: "Log in" }),
    ).toBeVisible();

    await this.page.getByLabel("Email").fill(user.email);
    await this.page.getByLabel("Password").fill(user.password);
    await this.page.getByRole("button", { name: "Log in" }).click();

    await expect(
      this.page.getByRole("button", { name: user.name }),
    ).toBeVisible();
  }

  async logout() {
    await this.page.goto("/logout");

    await expect(
      this.page.getByRole("heading", { name: "Welcome to Plausible!" }),
    ).toBeVisible();
  }
}

export class SitePage {
  constructor(
    public readonly page: Page,
    public readonly request: Request,
  ) {}

  async create(domain: string) {
    await this.page.goto("/sites/new");

    await expect(
      this.page.getByRole("button", { name: "Install Plausible" }),
    ).toBeVisible();

    await this.page.getByLabel("Domain").fill(domain);
    await this.page.getByLabel("Reporting timezone").selectOption("Etc/UTC");

    await this.page.getByRole("button", { name: "Install Plausible" }).click();

    await expect(
      this.page.getByRole("button", { name: "Verify Script installation" }),
    ).toBeVisible();
  }

  async setPublic(domain: string) {
    await this.page.goto(`/${domain}/settings/visibility`);

    await this.page
      .getByRole("form", { name: "Make stats publicly available" })
      .getByRole("button")
      .click();

    await expect(this.page.locator("body")).toContainText("are now public");
  }

  async populateStats(domain: string, events: object[]) {
    const payload = {
      domain: domain,
      events: events,
    };

    const response = await this.request.post("/e2e-tests/stats", {
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      data: { domain: domain, events: events },
    });

    expect(response.ok()).toBeTruthy();
  }
}

export function randomID() {
  return Math.random().toString(16).slice(2);
}

type SetupSiteContext = {
  sitePage: SitePage;
  authPage: AuthPage;
  domain: string;
  user: User;
};

export async function setupSite(
  page: Page,
  request: Request,
): SetupSiteContext {
  const domain = `${randomID()}.example.com`;

  const userID = randomID();

  const user: User = {
    name: `User ${userID}`,
    email: `email-${userID}@example.com`,
    password: "VeryStrongVerySecret",
  };

  const authPage = new AuthPage(page, request);
  await authPage.register(user);
  const sitePage = new SitePage(page, request);
  await sitePage.create(domain);

  return { sitePage, authPage, domain, user };
}
