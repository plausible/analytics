import type { Page, Request } from "@playwright/test";
import { expect } from "@playwright/test";

export async function expectLiveViewConnected(page: Page) {
  return expect(page.locator(".phx-connected")).toHaveCount(1);
}

export function randomID() {
  return Math.random().toString(16).slice(2);
}
