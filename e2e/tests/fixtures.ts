import type { Page, Request } from "@playwright/test";
import { expect } from "@playwright/test";
import { expectLiveViewConnected, randomID } from "./test-utils.ts";

type User = {
  name: string;
  email: string;
  password: string;
};

type EventTimestamp =
  | { minutesAgo: number }
  | { hoursAgo: number }
  | { daysAgo: number };

type Event = {
  name: string;
  pathname?: string;
  timestamp?: EventTimestamp;
};

export async function register({
  page,
  request,
  user,
}: {
  page: Page;
  request: Request;
  user: User;
}) {
  await page.goto("/register");

  await expectLiveViewConnected(page);

  await expect(
    page.getByRole("button", { name: "Start my free trial" }),
  ).toBeVisible();

  await page.getByLabel("Full name").fill(user.name);
  await page.getByLabel("Email").fill(user.email);
  await page.getByLabel("Password", { exact: true }).fill(user.password);
  await page
    .getByLabel("Confirm password", { exact: true })
    .fill(user.password);
  await expect(
    page.getByRole("button", { name: "Start my free trial" }),
  ).toBeEnabled();
  await page.getByRole("button", { name: "Start my free trial" }).click();

  await expect(
    page.getByRole("heading", { name: "Activate your account" }),
  ).toBeVisible();

  const response = await request.get("/sent-emails-api/emails.json");

  const emailData = await response.json();

  const emails = emailData.filter(
    (e) =>
      e.to[0][0] === user.name &&
      e.subject.indexOf("is your Plausible email verification code") > -1,
  );

  expect(emails.length).toEqual(1);

  const [code] = emails[0].subject.split(" ");

  await page.locator("input[name=code]").fill(code);

  await page.getByRole("button", { name: "Activate" }).click();

  await expect(
    page.getByRole("button", { name: "Install Plausible" }),
  ).toBeVisible();
}

export async function login({ page, user }: { page: Page; user: User }) {
  await page.goto("/login");

  await expect(page.getByRole("button", { name: "Log in" })).toBeVisible();

  await page.getByLabel("Email").fill(user.email);
  await page.getByLabel("Password").fill(user.password);
  await page.getByRole("button", { name: "Log in" }).click();

  await expect(page.getByRole("button", { name: user.name })).toBeVisible();
}

export async function logout(page: Page) {
  await page.goto("/logout");

  await expect(
    page.getByRole("heading", { name: "Welcome to Plausible!" }),
  ).toBeVisible();
}

export async function addSite({
  page,
  domain,
}: {
  page: Page;
  domain: string;
}) {
  await page.goto("/sites/new");

  await expect(
    page.getByRole("button", { name: "Install Plausible" }),
  ).toBeVisible();

  await page.getByLabel("Domain").fill(domain);
  await page.getByLabel("Reporting timezone").selectOption("Etc/UTC");

  await page.getByRole("button", { name: "Install Plausible" }).click();

  await expect(
    page.getByRole("button", { name: "Verify Script installation" }),
  ).toBeVisible();
}

export async function makeSitePublic({
  page,
  domain,
}: {
  page: Page;
  domain: string;
}) {
  await page.goto(`/${domain}/settings/visibility`);

  await page
    .getByRole("form", { name: "Make stats publicly available" })
    .getByRole("button")
    .click();

  await expect(page.locator("body")).toContainText("are now public");
}

export async function populateStats({
  request,
  domain,
  events,
}: {
  request: Request;
  domain: string;
  events: Event[];
}) {
  const payload = {
    domain: domain,
    events: events,
  };

  const response = await request.post("/e2e-tests/stats", {
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    data: { domain: domain, events: events },
  });

  expect(response.ok()).toBeTruthy();
}

export async function setupSite({
  page,
  request,
}: {
  page: Page;
  request: Request;
}): { domain: string; user: user } {
  const domain = `${randomID()}.example.com`;

  const userID = randomID();

  const user: User = {
    name: `User ${userID}`,
    email: `email-${userID}@example.com`,
    password: "VeryStrongVerySecret",
  };

  await register({ page, request, user });
  await addSite({ page, domain });

  return { domain, user };
}
