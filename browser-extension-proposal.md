# Browser Extension Proposal for LLM-Assisted Playwright Generation

**Date:** 2025-11-23
**Goal:** Record browser workflows and generate Playwright tests using LLM, without requiring LLM at runtime

## Your Requirements

### Data Capture Needed:
1. ✅ URL of each page visited
2. ✅ Page content (HTML) and screenshots
3. ✅ Before/after interaction state (delay on clicks/types to capture)
4. ✅ Element selectors that were clicked, typed, or interacted with
5. ✅ File download information
6. ✅ Network calls (HAR format preferred)

### Output Requirements:
- AI-ready summary (all at once or step-wise)
- Feed to LLM to generate Playwright code
- **No LLM required during test execution** (static Playwright tests)

---

## Existing Solutions Analysis

### Option 1: DeploySentinel Recorder (Best Match)

**GitHub:** https://github.com/DeploySentinel/Recorder

#### What It Captures:
- ✅ Clicks, keyboard inputs, window resizes, scroll events
- ✅ Hover events (via context menu)
- ✅ Element selectors (id, class, aria-label, data-testid)
- ✅ Full-page screenshots
- ⚠️ **Missing:** Page content HTML, network calls, before/after state delay
- ⚠️ **Missing:** File download tracking

#### Export Format:
- Directly generates Playwright/Puppeteer/Cypress code
- Uses smart selector strategy (id > aria > data-testid > fallback)

#### Architecture:
- React + TypeScript
- Chrome & Firefox support
- Active maintenance

#### Pros:
- Open source, actively maintained
- Multi-framework support
- Good selector strategy
- Screenshot support

#### Cons:
- No HAR network capture
- No HTML content capture
- No LLM integration
- Generates code directly (not intermediate format for LLM)

---

### Option 2: Chrome DevTools Recorder (Built-in)

**Feature:** Built into Chrome 92+ DevTools

#### What It Captures:
- ✅ User interactions (clicks, types, navigation)
- ✅ Selectors (CSS, XPath, pierce strategies)
- ⚠️ **Missing:** Screenshots, page content, network data

#### Export Format:
- **JSON format** with structured recording
- Can export via Playwright Chrome Recorder extension

#### Example JSON Structure:
```json
{
  "title": "Recording",
  "steps": [
    {
      "type": "click",
      "selectors": [
        ["aria/Submit"],
        ["#submit-btn"],
        ["xpath///*[@id='submit-btn']"]
      ],
      "offsetX": 10,
      "offsetY": 10
    }
  ]
}
```

#### Pros:
- Built into Chrome (no extension needed)
- JSON export format (good for LLM processing)
- Multiple selector strategies
- Official support

#### Cons:
- No screenshots
- No network capture
- No HTML content
- Basic interaction recording only

---

### Option 3: Headless Recorder (Deprecated)

**GitHub:** https://github.com/checkly/headless-recorder
**Status:** Deprecated as of Dec 2022

#### What It Captured:
- Clicks, types, form submissions
- Screenshots (full page + element)
- CSS selectors

#### Why Not Recommended:
- No longer maintained
- Missing network/content capture
- Better alternatives available

---

### Option 4: Capture Page State (Screenshot + HAR + Console)

**Extension:** Capture Page State

#### What It Captures:
- ✅ Screenshots
- ✅ HAR network logs
- ✅ Console logs
- ⚠️ **Missing:** Interaction recording, selectors

#### Use Case:
- Debugging, not workflow recording
- Good for capturing state snapshots

#### Pros:
- Comprehensive state capture
- HAR export included

#### Cons:
- Doesn't record interactions
- No selector tracking
- Not designed for test generation

---

## Recommended Solution: Custom Extension

None of the existing tools capture **all** your requirements. I recommend building a custom Chrome extension that:

### Architecture

```
Browser Extension (Chrome/Firefox)
├── Background Script (coordination)
├── Content Script (DOM interaction capture)
├── DevTools Panel (UI for control)
└── Storage/Export Module (JSON + HAR output)
```

### Data Capture Strategy

#### 1. URL Tracking
```javascript
// Background script
chrome.webNavigation.onCompleted.addListener((details) => {
  recordPageVisit({
    url: details.url,
    timestamp: Date.now(),
    frameId: details.frameId
  });
});
```

#### 2. Page Content & Screenshots
```javascript
// Content script - capture on page load and before interactions
async function capturePage() {
  const snapshot = {
    url: window.location.href,
    html: document.documentElement.outerHTML,
    screenshot: await chrome.runtime.sendMessage({ action: 'captureTab' }),
    timestamp: Date.now()
  };
  return snapshot;
}
```

#### 3. Interaction Capture with Delay
```javascript
// Content script - intercept and delay interactions
let pendingInteraction = null;

document.addEventListener('click', async (e) => {
  // Capture BEFORE state
  const beforeState = await capturePage();

  // Record interaction details
  const interaction = {
    type: 'click',
    element: getElementSelector(e.target),
    position: { x: e.clientX, y: e.clientY },
    beforeState: beforeState
  };

  // Delay for 1 second (allow state to settle)
  pendingInteraction = interaction;
  setTimeout(async () => {
    // Capture AFTER state
    interaction.afterState = await capturePage();
    recordInteraction(interaction);
    pendingInteraction = null;
  }, 1000);
}, true);

// Similar for keypress/input
document.addEventListener('input', async (e) => {
  // Same pattern with delay
}, true);
```

#### 4. Smart Selector Generation
```javascript
function getElementSelector(element) {
  const selectors = [];

  // Priority 1: data-testid
  if (element.dataset.testid) {
    selectors.push({ type: 'testid', value: element.dataset.testid });
  }

  // Priority 2: id
  if (element.id) {
    selectors.push({ type: 'id', value: element.id });
  }

  // Priority 3: aria-label
  const ariaLabel = element.getAttribute('aria-label');
  if (ariaLabel) {
    selectors.push({ type: 'aria', value: ariaLabel });
  }

  // Priority 4: role + name
  const role = element.getAttribute('role') || element.tagName.toLowerCase();
  const text = element.textContent?.trim().substring(0, 50);
  if (text) {
    selectors.push({ type: 'role', role, name: text });
  }

  // Priority 5: CSS selector (fallback)
  selectors.push({ type: 'css', value: getCSSPath(element) });

  // Priority 6: XPath (last resort)
  selectors.push({ type: 'xpath', value: getXPath(element) });

  return {
    primary: selectors[0],
    alternatives: selectors.slice(1),
    element: {
      tag: element.tagName,
      text: text,
      attributes: Array.from(element.attributes).map(attr => ({
        name: attr.name,
        value: attr.value
      }))
    }
  };
}
```

#### 5. Network Capture (HAR)
```javascript
// Use chrome.devtools.network API
chrome.devtools.network.onRequestFinished.addListener((request) => {
  request.getContent((content, encoding) => {
    recordNetworkCall({
      url: request.request.url,
      method: request.request.method,
      status: request.response.status,
      headers: request.request.headers,
      responseHeaders: request.response.headers,
      content: content,
      encoding: encoding,
      timing: request.time
    });
  });
});

// Or export complete HAR
chrome.devtools.network.getHAR((har) => {
  exportHAR(har);
});
```

#### 6. File Download Tracking
```javascript
// Background script
chrome.downloads.onCreated.addListener((downloadItem) => {
  recordDownload({
    url: downloadItem.url,
    filename: downloadItem.filename,
    timestamp: Date.now(),
    trigger: currentInteraction // Link to last interaction
  });
});
```

### Export Format: AI-Ready JSON

```json
{
  "recording": {
    "id": "rec_12345",
    "startTime": "2025-11-23T10:00:00Z",
    "endTime": "2025-11-23T10:05:30Z",
    "baseUrl": "https://app.example.com"
  },
  "steps": [
    {
      "id": "step_1",
      "type": "navigation",
      "timestamp": 1700740800000,
      "url": "https://app.example.com/login",
      "beforeState": {
        "screenshot": "data:image/png;base64,...",
        "html": "<!DOCTYPE html>...",
        "viewport": { "width": 1920, "height": 1080 }
      }
    },
    {
      "id": "step_2",
      "type": "click",
      "timestamp": 1700740805000,
      "element": {
        "selectors": {
          "primary": { "type": "testid", "value": "email-input" },
          "alternatives": [
            { "type": "id", "value": "email" },
            { "type": "role", "role": "textbox", "name": "Email" },
            { "type": "css", "value": "input[type='email']" }
          ]
        },
        "tag": "INPUT",
        "attributes": [
          { "name": "type", "value": "email" },
          { "name": "name", "value": "email" },
          { "name": "data-testid", "value": "email-input" }
        ]
      },
      "beforeState": {
        "screenshot": "data:image/png;base64,...",
        "html": "...",
        "network": []
      },
      "afterState": {
        "screenshot": "data:image/png;base64,...",
        "html": "...",
        "network": [
          {
            "url": "/api/validate-email",
            "method": "POST",
            "status": 200
          }
        ]
      }
    },
    {
      "id": "step_3",
      "type": "input",
      "timestamp": 1700740807000,
      "element": {
        "selectors": {
          "primary": { "type": "testid", "value": "email-input" }
        }
      },
      "value": "user@example.com",
      "beforeState": { /* ... */ },
      "afterState": { /* ... */ }
    },
    {
      "id": "step_4",
      "type": "download",
      "timestamp": 1700740820000,
      "trigger": "step_3",
      "file": {
        "url": "https://app.example.com/export.csv",
        "filename": "export.csv"
      }
    }
  ],
  "har": {
    "log": {
      "version": "1.2",
      "creator": { "name": "Custom Recorder", "version": "1.0" },
      "entries": [ /* HAR entries */ ]
    }
  },
  "summary": {
    "totalSteps": 4,
    "totalDuration": 330000,
    "pagesVisited": 2,
    "interactions": 3,
    "networkCalls": 5,
    "downloads": 1
  }
}
```

---

## LLM Integration Workflow

### Step 1: Record Workflow (Browser Extension)

User performs manual testing:
1. Opens extension
2. Clicks "Start Recording"
3. Performs test scenario
4. Clicks "Stop Recording"
5. Extension generates JSON file

### Step 2: Export AI-Ready Summary

Two export modes:

**Mode A: Complete Export**
```json
{
  "recording": { /* metadata */ },
  "steps": [ /* all steps */ ],
  "har": { /* network log */ }
}
```

**Mode B: Step-by-Step Export**
```json
// Each step as separate file
{
  "step": 1,
  "description": "Navigate to login page",
  "data": { /* step details */ }
}
```

### Step 3: LLM Generates Playwright

Feed the JSON to LLM (Claude, GPT-4, etc.) with prompt:

```
You are an expert Playwright test generator. Convert this browser recording
into a robust Playwright test following best practices:

1. Use semantic locators (getByRole, getByLabel, getByTestId)
2. Add auto-waiting assertions
3. Implement proper error handling
4. Include visual regression for critical steps
5. Add comments explaining business logic
6. Use Page Object Model if multiple pages involved

Recording data:
[JSON]

Generate a complete Playwright test file.
```

### Step 4: LLM Output - Static Playwright Test

```typescript
import { test, expect } from '@playwright/test';

test.describe('User login flow', () => {
  test('should login successfully', async ({ page }) => {
    // Navigate to login page
    await page.goto('/login');
    await expect(page).toHaveURL(/\/login/);

    // Screenshot for visual regression
    await expect(page).toHaveScreenshot('login-page.png');

    // Fill email - using semantic locator from recording
    await page.getByRole('textbox', { name: 'Email' }).fill('user@example.com');

    // Fill password
    await page.getByLabel('Password').fill('password123');

    // Submit form
    await page.getByRole('button', { name: 'Sign in' }).click();

    // Wait for navigation
    await page.waitForURL(/\/dashboard/);

    // Verify successful login
    await expect(page.getByText('Welcome back')).toBeVisible();
    await expect(page).toHaveScreenshot('dashboard.png');
  });
});
```

### Step 5: Manual Refinement

Developer reviews and adjusts:
- Add test data management
- Implement authentication fixtures
- Add edge cases
- Configure for CI/CD

### Step 6: Run Tests (No LLM Required)

```bash
npx playwright test
```

---

## Implementation Options

### Option A: Extend DeploySentinel Recorder (Fastest)

**Effort:** Low-Medium
**Timeline:** 1-2 weeks

Fork DeploySentinel Recorder and add:
1. Page content (HTML) capture
2. HAR network export
3. Before/after state with delay
4. JSON export format (in addition to direct code generation)
5. File download tracking

**Pros:**
- Existing foundation (React, TypeScript)
- Proven selector strategy
- Multi-framework support

**Cons:**
- Need to understand existing codebase
- May have architectural constraints

**Repository:** https://github.com/DeploySentinel/Recorder

---

### Option B: Build Custom Extension from Scratch (Most Control)

**Effort:** Medium-High
**Timeline:** 3-4 weeks

Build new extension with:
- Clean architecture for your exact requirements
- Optimized JSON export format
- Custom UI for recording control
- Advanced selector strategies
- HAR integration
- Before/after state capture with configurable delay

**Pros:**
- Complete control over features
- Optimized for LLM integration
- No legacy code constraints

**Cons:**
- More development time
- Need to build everything

**Tech Stack:**
- TypeScript + React
- Chrome Extension Manifest V3
- Webpack/Vite for bundling
- HAR library for network export

---

### Option C: Hybrid Approach (Recommended)

**Effort:** Medium
**Timeline:** 2-3 weeks

Use existing tools + custom glue:

1. **DeploySentinel Recorder** - For interaction recording and selector generation
2. **Capture Page State** - For screenshots + HAR
3. **Custom Script** - Merge outputs into single AI-ready JSON

**Architecture:**
```
User performs workflow
    ↓
DeploySentinel captures: clicks, types, selectors
Capture Page State captures: screenshots, HAR, console
    ↓
Custom Node.js script merges both outputs
    ↓
Generate unified JSON with all data
    ↓
Feed to LLM → Playwright test generated
```

**Pros:**
- Leverage existing tools
- Quick to implement
- Lower maintenance burden

**Cons:**
- Need to coordinate two extensions
- Less seamless UX
- May have data sync issues

---

## Detailed Custom Extension Specification

If building custom extension (Option B), here's the complete spec:

### Features

1. **Recording Control**
   - Start/Stop/Pause recording
   - Manual step annotation
   - Step deletion/editing
   - Bookmark important states

2. **Data Capture**
   - ✅ All URL navigations
   - ✅ Full page HTML at each step
   - ✅ Screenshots (before/after interactions)
   - ✅ Click/type/scroll interactions
   - ✅ Smart selectors (multiple strategies)
   - ✅ Network calls (HAR format)
   - ✅ File downloads
   - ✅ Form submissions
   - ✅ Iframe interactions

3. **Export Options**
   - JSON (complete recording)
   - JSON (step-by-step)
   - HAR (network only)
   - Screenshots (ZIP)
   - Markdown summary (human-readable)

4. **LLM Integration**
   - AI-optimized JSON format
   - Include context and metadata
   - Configurable detail level
   - Direct API integration (optional)

### UI/UX

```
┌─────────────────────────────────────┐
│ Browser Automation Recorder   [⚙️]  │
├─────────────────────────────────────┤
│                                     │
│  ⏺️  Start Recording                │
│  ⏸️  Pause                          │
│  ⏹️  Stop & Export                  │
│                                     │
├─────────────────────────────────────┤
│  Recording: 5 steps (2m 30s)       │
│                                     │
│  1. Navigate to /login             │
│  2. Click email input              │
│  3. Type "user@example.com"        │
│  4. Click password input           │
│  5. Type "******"                  │
│                                     │
│  [Edit] [Delete] [Add Annotation]  │
│                                     │
├─────────────────────────────────────┤
│  Export Options:                   │
│  □ Complete JSON                   │
│  □ Step-by-Step JSON               │
│  □ HAR File                        │
│  □ Screenshots                     │
│  □ Markdown Summary                │
│                                     │
│  [Export] [Generate Playwright]    │
└─────────────────────────────────────┘
```

### File Structure

```
browser-automation-recorder/
├── manifest.json
├── src/
│   ├── background/
│   │   ├── background.ts          # Background service worker
│   │   └── network-capture.ts     # HAR recording
│   ├── content/
│   │   ├── content.ts             # DOM interaction capture
│   │   ├── selector-generator.ts  # Smart selector creation
│   │   └── state-capture.ts       # HTML + screenshot capture
│   ├── devtools/
│   │   ├── panel.tsx              # DevTools panel UI
│   │   └── panel.html
│   ├── popup/
│   │   ├── popup.tsx              # Extension popup UI
│   │   └── popup.html
│   ├── shared/
│   │   ├── types.ts               # TypeScript types
│   │   ├── storage.ts             # Chrome storage wrapper
│   │   └── export.ts              # Export formats
│   └── llm/
│       ├── prompt-generator.ts    # LLM prompt creation
│       └── api-integration.ts     # Optional LLM API calls
├── public/
│   ├── icons/
│   └── styles/
└── package.json
```

---

## LLM Prompt Templates

### Template 1: Basic Test Generation

```
You are an expert Playwright test engineer. Generate a Playwright test from this
browser recording.

Requirements:
- Use semantic locators (getByRole, getByLabel)
- Add auto-waiting assertions
- Include visual regression on key pages
- Add descriptive comments
- Handle errors gracefully

Recording:
{JSON}

Output: Complete Playwright test file in TypeScript
```

### Template 2: Page Object Model Generation

```
Generate a Playwright Page Object Model from this recording.

Create:
1. Page class for each unique page
2. Locators using semantic selectors
3. Action methods for interactions
4. Test file using the page objects

Recording:
{JSON}

Output: Multiple files (pages/*.ts and test.spec.ts)
```

### Template 3: Test Criteria from Plain Text

```
User requirement: "{PLAIN_TEXT_REQUIREMENT}"

Browser recording: {JSON}

Generate a Playwright test that:
1. Implements the exact workflow from the recording
2. Validates all criteria from the user requirement
3. Adds assertions for expected behavior
4. Includes error cases mentioned in requirements

Output: Complete test file with all criteria validated
```

---

## Cost & Effort Estimation

### Option A: Extend DeploySentinel
- **Development:** 40-60 hours
- **Testing:** 10-15 hours
- **Documentation:** 5-8 hours
- **Total:** 55-83 hours (~2 weeks)

### Option B: Custom Extension
- **Architecture & Setup:** 15-20 hours
- **Core Recording:** 30-40 hours
- **HAR Integration:** 10-15 hours
- **Export Formats:** 10-12 hours
- **UI Development:** 20-25 hours
- **Testing:** 15-20 hours
- **Documentation:** 8-10 hours
- **Total:** 108-142 hours (~3-4 weeks)

### Option C: Hybrid Approach
- **Script Development:** 20-30 hours
- **Integration Testing:** 10-15 hours
- **Documentation:** 5-8 hours
- **Total:** 35-53 hours (~1-2 weeks)

---

## Recommended Path Forward

### Phase 1: Proof of Concept (Week 1)
**Use Option C (Hybrid)**

1. Install DeploySentinel Recorder
2. Install Capture Page State (or use Chrome DevTools for HAR)
3. Create Node.js script to merge outputs
4. Test with simple workflow
5. Feed merged JSON to Claude/GPT-4
6. Validate generated Playwright test

**Deliverable:** Working prototype that proves the concept

### Phase 2: Refinement (Week 2)
If PoC successful:

**Option 1:** Continue with hybrid if acceptable
**Option 2:** Fork DeploySentinel and add missing features
**Option 3:** Start custom extension development

**Deliverable:** Production-ready recording solution

### Phase 3: LLM Integration (Week 3)
1. Create prompt templates
2. Build export pipeline
3. Test with multiple workflows
4. Refine generated tests
5. Document patterns

**Deliverable:** End-to-end workflow from recording to test

---

## Example Workflow

### Scenario: Test Login Flow

**Step 1: Record**
```
1. Open extension, click "Start Recording"
2. Navigate to https://app.example.com/login
3. Click email field
4. Type "user@example.com"
5. Click password field
6. Type "password123"
7. Click "Sign in" button
8. Verify dashboard loads
9. Click "Stop Recording"
```

**Step 2: Export**
Extension generates `recording-login-20251123.json`:
```json
{
  "recording": { /* metadata */ },
  "steps": [
    { "type": "navigation", "url": "/login", /* ... */ },
    { "type": "click", "element": { /* email field */ }, /* ... */ },
    { "type": "input", "value": "user@example.com", /* ... */ },
    /* ... more steps ... */
  ],
  "har": { /* network data */ }
}
```

**Step 3: LLM Generation**
```bash
# CLI tool or manual
cat recording-login-20251123.json | llm-to-playwright > tests/login.spec.ts
```

Or via API:
```typescript
const recording = readFileSync('recording-login-20251123.json');
const prompt = generatePrompt(recording);
const playwrightCode = await anthropic.messages.create({
  model: 'claude-3-5-sonnet-20241022',
  messages: [{ role: 'user', content: prompt }],
});

writeFileSync('tests/login.spec.ts', playwrightCode);
```

**Step 4: Manual Review**
Developer reviews `tests/login.spec.ts`:
- Adjust assertions
- Add fixtures for authentication
- Configure test data

**Step 5: Run Tests**
```bash
npx playwright test tests/login.spec.ts
```

---

## Conclusion

### Recommended Solution

**Start with Option C (Hybrid)** for proof of concept:
- Use DeploySentinel Recorder for interactions
- Use Chrome DevTools for HAR export
- Build merge script for JSON generation
- Feed to Claude/GPT-4 for Playwright generation

**If successful, migrate to Option A** (extend DeploySentinel):
- Fork and add missing features
- Optimize for your workflow
- Maintain open source contribution

### Key Benefits

✅ **No MCP dependency** - Pure browser extension approach
✅ **No LLM at runtime** - Generated tests are static Playwright
✅ **Complete data capture** - URLs, content, screenshots, selectors, network, downloads
✅ **LLM-optimized export** - JSON format designed for AI processing
✅ **Flexible workflow** - All-at-once or step-by-step generation
✅ **Manual refinement** - Full control over generated tests

### Next Steps

1. **Validate approach** - Try Option C with existing tools
2. **Review generated tests** - Ensure quality meets requirements
3. **Decide on implementation** - Option A, B, or C based on results
4. **Build & iterate** - Develop chosen solution
5. **Integrate with CI/CD** - Add to deployment pipeline

---

## Sources

### Browser Extensions
- [DeploySentinel Recorder](https://github.com/DeploySentinel/Recorder)
- [Headless Recorder](https://github.com/checkly/headless-recorder)
- [Playwright Chrome Recorder](https://github.com/AndrewUsher/playwright-chrome-recorder)
- [Playwright CRX](https://github.com/ruifigueira/playwright-crx)
- [Chrome DevTools Recorder](https://developer.chrome.com/docs/devtools/recorder/)

### Network Capture
- [Capture Page State Extension](https://dev.to/salhernandez/get-screenshot-console-logs-har-log-using-capture-page-state-chrome-extension-4ona)
- [Chrome DevTools Network Reference](https://developer.chrome.com/docs/devtools/network/reference)

### Playwright Resources
- [Playwright Official Docs](https://playwright.dev)
- [Playwright Test Generation](https://playwright.dev/docs/codegen)

---

**Ready to proceed?** Let me know which option you'd like to explore first!
