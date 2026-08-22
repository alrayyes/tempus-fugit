import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

// WCAG 2.1 AA, axe's own default when no tags are given - see rules/a11y.md.
const WCAG_TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"];

test("the landing page runs its timer and meets WCAG 2.1 AA", async ({
	page,
}) => {
	await page.goto("/");
	await expect(page).toHaveTitle("Make it worthwhile | Tempus Fugit");

	const timer = page.locator("#timer");
	await expect(timer).toBeVisible();
	const firstReading = await timer.textContent();
	await expect(timer).not.toHaveText(firstReading ?? "", { timeout: 2000 });

	const { violations } = await new AxeBuilder({ page })
		.withTags(WCAG_TAGS)
		.analyze();
	expect(violations).toEqual([]);
});

test("the 404 page has no timer and meets WCAG 2.1 AA", async ({ page }) => {
	await page.goto("/no-such-page");
	await expect(page).toHaveTitle("404: Not found | Tempus Fugit");
	await expect(page.locator("#timer")).toHaveCount(0);

	const { violations } = await new AxeBuilder({ page })
		.withTags(WCAG_TAGS)
		.analyze();
	expect(violations).toEqual([]);
});
