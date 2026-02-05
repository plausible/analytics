import { test, expect } from "@playwright/test";

const baseUrl = process.env.BASE_URL;

test("dashboard renders", async ({ page }) => {
  await page.goto("/public.example.com");

  await expect(page).toHaveTitle(/Plausible/);

  await expect(
    page.getByRole("button", { name: "public.exampleaaa.com" }),
  ).toBeVisible();
});

test("filter is applied", async ({ page }) => {
  await page.goto("/public.example.com");

  await expect(page.getByRole("link", { name: "Page" })).toBeHidden();

  await page.getByRole("button", { name: "Filter" }).click();

  await expect(page.getByRole("link", { name: "Page" })).toHaveCount(1);

  await page.getByRole("link", { name: "Page" }).click();

  await expect(page).toHaveURL(baseUrl + "/public.example.com/filter/page");

  await expect(
    page.getByRole("heading", { name: "Filter by Page" }),
  ).toBeVisible();

  await expect(
    page.getByRole("button", { name: "Apply filter", disabled: true }),
  ).toHaveCount(1);

  await page.getByPlaceholder("Select a Page").click();

  await expect(
    page.getByRole("button", { name: "Apply filter", disabled: true }),
  ).toHaveCount(1);

  await expect(
    page.getByRole("listitem").filter({ hasText: "/page1" }),
  ).toBeVisible();

  await expect(
    page.getByRole("listitem").filter({ hasText: "/page2" }),
  ).toBeVisible();

  await expect(
    page.getByRole("listitem").filter({ hasText: "/page3" }),
  ).toBeVisible();

  await expect(
    page.getByRole("listitem").filter({ hasText: "/other" }),
  ).toBeVisible();

  await page.getByPlaceholder("Select a Page").fill("pag");

  await expect(
    page.getByRole("listitem").filter({ hasText: "/page1" }),
  ).toBeVisible();

  await expect(
    page.getByRole("listitem").filter({ hasText: "/page2" }),
  ).toBeVisible();

  await expect(
    page.getByRole("listitem").filter({ hasText: "/page3" }),
  ).toBeVisible();

  await expect(
    page.getByRole("listitem").filter({ hasText: "/other" }),
  ).toBeHidden();

  await page.getByRole("listitem").filter({ hasText: "/page1" }).click();

  await expect(
    page.getByRole("button", { name: "Apply filter", disabled: false }),
  ).toHaveCount(1);

  await page.getByRole("button", { name: "Apply filter" }).click();

  await expect(page).toHaveURL(
    baseUrl + "/public.example.com?f=is,page,/page1",
  );

  await expect(
    page.getByRole("link", { name: "Page is /page1" }),
  ).toHaveAttribute("title", "Edit filter: Page is /page1");
});

test("tab selection user preferences are preserved across reloads", async ({
  page,
}) => {
  await page.goto("/public.example.com");

  await page.getByRole("button", { name: "Entry pages" }).click();

  await page.goto("/public.example.com");

  let currentTab = await page.evaluate(() =>
    localStorage.getItem("pageTab__public.example.com"),
  );

  await expect(currentTab).toEqual("entry-pages");

  await page.getByRole("button", { name: "Exit pages" }).click();

  await page.goto("/public.example.com");

  currentTab = await page.evaluate(() =>
    localStorage.getItem("pageTab__public.example.com"),
  );

  await expect(currentTab).toEqual("exit-pages");
});

test("back navigation closes the modal", async ({ page }) => {
  await page.goto("/public.example.com");

  await page.getByRole("button", { name: "Filter" }).click();

  await page.getByRole("link", { name: "Page" }).click();

  await expect(page).toHaveURL(baseUrl + "/public.example.com/filter/page");

  await page.goBack();

  await expect(page).toHaveURL(baseUrl + "/public.example.com");
});

test("opens for logged in user", async ({ page }) => {
  await page.goto("/login");

  await page.getByLabel("Email").fill("user@plausible.test");

  await page.getByLabel("Password").fill("plausible");

  await page.getByRole("button", { name: "Log in" }).click();

  await page.goto("/private.example.com");

  await expect(
    page.getByRole("button", { name: "private.example.com" }),
  ).toBeVisible();
});
