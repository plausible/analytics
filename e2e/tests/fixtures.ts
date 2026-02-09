import type { Page, Request } from "@playwright/test";
import { expect } from "@playwright/test";

type User = {
  name: string;
  email: string;
  password: string;
};

export class AuthPage {
  constructor(public readonly page: Page) {}

  async register(user: User) {
    await this.page.goto("/register");
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

    await this.page.goto("/sent-emails");

    await expect(this.page.locator(".email-detail-subject")).toBeVisible();

    const subject = await this.page
      .locator(".email-detail-subject")
      .textContent();
    const [code, ...rest] = subject.split(" ");

    await expect(rest.join(" ")).toEqual(
      "is your Plausible email verification code",
    );

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
