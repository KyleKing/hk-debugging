#!/usr/bin/env node

/**
 * Generate Playwright test template
 * Usage: node generate-test-template.js <test-name> [--pom]
 */

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const testName = args[0];
const usePOM = args.includes('--pom');

if (!testName) {
  console.error('Usage: node generate-test-template.js <test-name> [--pom]');
  process.exit(1);
}

const kebabCase = (str) => str.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase();
const pascalCase = (str) => str.replace(/(^\w|-\w)/g, (m) => m.replace('-', '').toUpperCase());

const fileName = `${kebabCase(testName)}.spec.ts`;
const pageName = pascalCase(testName);

// Basic test template
const basicTemplate = `import { test, expect } from '@playwright/test';

test.describe('${testName}', () => {
  test('should load successfully', async ({ page }) => {
    await page.goto('/');

    // Add your test logic here
    await expect(page).toHaveURL(/\\//);
  });

  test('should handle user interaction', async ({ page }) => {
    await page.goto('/');

    // Example interaction
    await page.getByRole('button', { name: 'Click me' }).click();

    // Add assertions
    await expect(page.getByText('Success')).toBeVisible();
  });
});
`;

// Page Object Model template
const pomTestTemplate = `import { test, expect } from '@playwright/test';
import { ${pageName}Page } from '../pages/${pageName}Page';

test.describe('${testName}', () => {
  let ${testName}Page: ${pageName}Page;

  test.beforeEach(async ({ page }) => {
    ${testName}Page = new ${pageName}Page(page);
    await ${testName}Page.goto();
  });

  test('should load successfully', async ({ page }) => {
    await expect(page).toHaveURL(/${testName}/);
  });

  test('should handle user interaction', async () => {
    await ${testName}Page.performAction();
    await ${testName}Page.expectSuccess();
  });
});
`;

const pageObjectTemplate = `import { Page, Locator, expect } from '@playwright/test';

export class ${pageName}Page {
  readonly page: Page;
  readonly heading: Locator;
  readonly actionButton: Locator;
  readonly successMessage: Locator;

  constructor(page: Page) {
    this.page = page;

    // Define locators using semantic selectors
    this.heading = page.getByRole('heading', { name: /${testName}/i });
    this.actionButton = page.getByRole('button', { name: 'Click me' });
    this.successMessage = page.getByText('Success');
  }

  async goto() {
    await this.page.goto('/${kebabCase(testName)}');
    await expect(this.heading).toBeVisible();
  }

  async performAction() {
    await this.actionButton.click();
  }

  async expectSuccess() {
    await expect(this.successMessage).toBeVisible();
  }
}
`;

// Create tests directory if it doesn't exist
const testsDir = path.join(process.cwd(), 'tests');
if (!fs.existsSync(testsDir)) {
  fs.mkdirSync(testsDir, { recursive: true });
}

// Write test file
const testPath = path.join(testsDir, fileName);
const testContent = usePOM ? pomTestTemplate : basicTemplate;

fs.writeFileSync(testPath, testContent);
console.log(`✓ Created test file: ${testPath}`);

// Create page object if using POM
if (usePOM) {
  const pagesDir = path.join(testsDir, 'pages');
  if (!fs.existsSync(pagesDir)) {
    fs.mkdirSync(pagesDir, { recursive: true });
  }

  const pagePath = path.join(pagesDir, `${pageName}Page.ts`);
  fs.writeFileSync(pagePath, pageObjectTemplate);
  console.log(`✓ Created page object: ${pagePath}`);
}

console.log('\nNext steps:');
console.log('1. Review and customize the generated test');
console.log('2. Update locators to match your application');
console.log('3. Add specific test cases for your requirements');
console.log(`4. Run: npx playwright test ${fileName}`);
