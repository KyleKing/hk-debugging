# DeploySentinel Recorder: Technical Modification Guide

**Goal:** Modify DeploySentinel Recorder to capture all required data for LLM-assisted Playwright test generation

**Date:** 2025-11-23

---

## Executive Summary

DeploySentinel Recorder is a solid foundation (90.7% TypeScript, React-based, multi-browser support) but needs 5 major additions:

1. **HAR Network Capture** - Currently missing, needs DevTools API integration
2. **HTML Content Capture** - Add DOM snapshot functionality
3. **Before/After State with Delay** - Intercept interactions with configurable delay
4. **Enhanced Export Format** - JSON output optimized for LLM consumption
5. **File Download Tracking** - Monitor chrome.downloads API

**Estimated Effort:** 40-60 hours (~2 weeks)
**Risk Level:** Medium (DevTools API integration most complex)

---

## Part 1: Current Architecture Analysis

### Repository Structure

```
DeploySentinel/Recorder/
├── src/
│   ├── background/           # Background service worker
│   ├── content/              # Content scripts (DOM injection)
│   ├── popup/                # Extension popup UI
│   ├── devtools/             # DevTools panel (if exists)
│   └── utils/                # Shared utilities
├── tests/
├── webpack.config.*.js       # Separate configs for Chrome/Firefox
├── manifest.chrome.json      # Chrome extension manifest
├── manifest.firefox.json     # Firefox extension manifest
└── package.json
```

### How Recording Currently Works

**1. Event Capture (Content Script)**
```typescript
// Simplified current flow
document.addEventListener('click', (event) => {
  const selector = generateSelector(event.target);
  recordEvent({
    type: 'click',
    selector: selector,
    timestamp: Date.now()
  });
}, true); // Capture phase
```

**2. Selector Generation**
Priority: `id` > `class` > `aria-label` > `alt` > `name` > `data-testid` > fallback

**3. Code Generation**
Converts events to Playwright/Cypress/Puppeteer code in real-time.

**4. Export**
Copies generated code to clipboard or displays in UI.

### What's Missing

❌ **Network calls (HAR)**
❌ **Page HTML content**
❌ **Screenshots** (partial - only manual triggers)
❌ **Before/after state capture**
❌ **Structured JSON export for LLM**
❌ **File download tracking**

---

## Part 2: Required Technical Changes

### Change 1: Add HAR Network Capture

**Challenge:** DevTools API requires a DevTools panel, can't work from content script alone.

#### Implementation Strategy

**A. Add DevTools Page (Required for HAR)**

Create `src/devtools/devtools.html`:
```html
<!DOCTYPE html>
<html>
<head>
  <title>DeploySentinel Recorder</title>
</head>
<body>
  <script src="devtools.js"></script>
</body>
</html>
```

Create `src/devtools/devtools.js`:
```typescript
// Create DevTools panel
chrome.devtools.panels.create(
  'Recorder',
  'icon.png',
  'panel.html',
  (panel) => {
    console.log('Recorder panel created');
  }
);

// Start HAR capture
let harLog: any[] = [];

chrome.devtools.network.onRequestFinished.addListener((request) => {
  request.getContent((content, encoding) => {
    const harEntry = {
      request: {
        method: request.request.method,
        url: request.request.url,
        headers: request.request.headers,
        queryString: request.request.queryString,
        postData: request.request.postData,
      },
      response: {
        status: request.response.status,
        statusText: request.response.statusText,
        headers: request.response.headers,
        content: {
          size: request.response.bodySize,
          mimeType: request.response.content.mimeType,
          text: content,
          encoding: encoding,
        },
      },
      startedDateTime: request.startedDateTime,
      time: request.time,
      timings: request.timings,
    };

    harLog.push(harEntry);

    // Send to background script for storage
    chrome.runtime.sendMessage({
      type: 'NETWORK_REQUEST',
      data: harEntry
    });
  });
});

// Export HAR on demand
function exportHAR() {
  chrome.devtools.network.getHAR((har) => {
    chrome.runtime.sendMessage({
      type: 'EXPORT_HAR',
      data: har
    });
  });
}
```

**B. Update Manifest**

In `manifest.chrome.json`:
```json
{
  "manifest_version": 3,
  "devtools_page": "devtools.html",
  "permissions": [
    "tabs",
    "activeTab",
    "storage",
    "downloads"
  ],
  "background": {
    "service_worker": "background.js"
  }
}
```

**C. Background Script Integration**

Modify `src/background/background.ts`:
```typescript
// Store HAR entries
let harEntries: any[] = [];
let isRecording = false;

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'START_RECORDING') {
    isRecording = true;
    harEntries = [];
  }

  if (message.type === 'STOP_RECORDING') {
    isRecording = false;
  }

  if (message.type === 'NETWORK_REQUEST' && isRecording) {
    harEntries.push({
      ...message.data,
      tabId: sender.tab?.id,
      timestamp: Date.now()
    });
  }

  if (message.type === 'GET_HAR') {
    sendResponse({ har: harEntries });
  }

  return true; // Keep channel open for async response
});
```

**⚠️ Key Issue:** DevTools API only captures requests while DevTools is open. This is a **fundamental Chrome limitation**.

**Workaround Options:**
1. **Accept limitation** - User must have DevTools open during recording
2. **Use declarativeNetRequest API** - Limited data, no response bodies
3. **Inject proxy** - Complex, requires HTTPS certificate handling

**Recommendation:** Start with Option 1, document requirement clearly.

---

### Change 2: HTML Content Capture

**Easier than HAR** - Content script has full DOM access.

#### Implementation

Modify `src/content/recorder.ts`:
```typescript
interface PageSnapshot {
  url: string;
  html: string;
  timestamp: number;
  viewport: {
    width: number;
    height: number;
  };
  scrollPosition: {
    x: number;
    y: number;
  };
}

function capturePageSnapshot(): PageSnapshot {
  return {
    url: window.location.href,
    html: document.documentElement.outerHTML,
    timestamp: Date.now(),
    viewport: {
      width: window.innerWidth,
      height: window.innerHeight
    },
    scrollPosition: {
      x: window.scrollX,
      y: window.scrollY
    }
  };
}

// Capture on page load
window.addEventListener('load', () => {
  const snapshot = capturePageSnapshot();
  chrome.runtime.sendMessage({
    type: 'PAGE_SNAPSHOT',
    data: snapshot
  });
});
```

**⚠️ Issue:** Large HTML can exceed message size limits (64MB theoretical, but ~1MB practical).

**Solution:** Compress or chunk large HTML:
```typescript
import pako from 'pako'; // Add to package.json

function capturePageSnapshot(): PageSnapshot {
  const html = document.documentElement.outerHTML;
  const compressed = pako.gzip(html);
  const base64 = btoa(String.fromCharCode(...compressed));

  return {
    url: window.location.href,
    htmlCompressed: base64,
    htmlSize: html.length,
    timestamp: Date.now(),
    // ... rest
  };
}
```

---

### Change 3: Screenshot Capture with Before/After

#### Current State
DeploySentinel has manual screenshot triggers. Need automatic before/after.

#### Implementation

**A. Add Screenshot Helper**

Create `src/utils/screenshot.ts`:
```typescript
export async function captureScreenshot(
  quality: number = 90
): Promise<string> {
  return new Promise((resolve, reject) => {
    chrome.runtime.sendMessage(
      { type: 'CAPTURE_SCREENSHOT', quality },
      (response) => {
        if (response.error) {
          reject(response.error);
        } else {
          resolve(response.dataUrl);
        }
      }
    );
  });
}
```

**B. Background Script Handler**

In `src/background/background.ts`:
```typescript
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'CAPTURE_SCREENSHOT') {
    chrome.tabs.captureVisibleTab(
      null,
      { format: 'png', quality: message.quality || 90 },
      (dataUrl) => {
        if (chrome.runtime.lastError) {
          sendResponse({ error: chrome.runtime.lastError.message });
        } else {
          sendResponse({ dataUrl });
        }
      }
    );
    return true; // Async response
  }
});
```

**C. Before/After Interaction Capture**

Modify `src/content/recorder.ts`:
```typescript
interface InteractionCapture {
  type: string;
  element: ElementInfo;
  beforeState: {
    snapshot: PageSnapshot;
    screenshot: string;
    networkPending: number; // Count of pending requests
  };
  afterState?: {
    snapshot: PageSnapshot;
    screenshot: string;
    networkCompleted: number;
  };
  timestamp: number;
}

// Configurable delay
const CAPTURE_DELAY_MS = 1000;

let pendingInteraction: InteractionCapture | null = null;

async function handleClick(event: MouseEvent) {
  // Prevent default to capture before state
  const beforeSnapshot = capturePageSnapshot();
  const beforeScreenshot = await captureScreenshot();

  const interaction: InteractionCapture = {
    type: 'click',
    element: getElementInfo(event.target as Element),
    beforeState: {
      snapshot: beforeSnapshot,
      screenshot: beforeScreenshot,
      networkPending: getActiveNetworkRequests().length
    },
    timestamp: Date.now()
  };

  // Store pending interaction
  pendingInteraction = interaction;

  // Let the click happen
  // (Don't call preventDefault - let default behavior occur)

  // Wait for state to settle, then capture after state
  setTimeout(async () => {
    if (pendingInteraction === interaction) {
      const afterSnapshot = capturePageSnapshot();
      const afterScreenshot = await captureScreenshot();

      interaction.afterState = {
        snapshot: afterSnapshot,
        screenshot: afterScreenshot,
        networkCompleted: getCompletedNetworkRequests().length
      };

      // Send complete interaction to background
      chrome.runtime.sendMessage({
        type: 'INTERACTION_CAPTURED',
        data: interaction
      });

      pendingInteraction = null;
    }
  }, CAPTURE_DELAY_MS);
}

// Register in capture phase to see event first
document.addEventListener('click', handleClick, true);
```

**⚠️ Issues:**

1. **Performance** - Capturing full HTML + screenshot on every click is expensive
2. **Storage** - Data accumulates quickly (MB per interaction)
3. **Race conditions** - User might click again before delay completes

**Solutions:**

1. **Throttle captures** - Only capture if no pending interaction
2. **Stream to IndexedDB** - Don't keep everything in memory
3. **Configurable detail levels** - Option to skip HTML or screenshots

```typescript
interface RecordingConfig {
  captureHTML: boolean;
  captureScreenshots: boolean;
  captureDelay: number;
  maxStorageSize: number; // MB
}

const DEFAULT_CONFIG: RecordingConfig = {
  captureHTML: true,
  captureScreenshots: true,
  captureDelay: 1000,
  maxStorageSize: 100
};
```

---

### Change 4: File Download Tracking

**Straightforward** - Chrome provides downloads API.

#### Implementation

In `src/background/background.ts`:
```typescript
let recordedDownloads: DownloadInfo[] = [];

interface DownloadInfo {
  id: number;
  url: string;
  filename: string;
  startTime: string;
  state: string;
  triggerInteraction?: string; // Link to interaction ID
}

chrome.downloads.onCreated.addListener((downloadItem) => {
  if (!isRecording) return;

  const download: DownloadInfo = {
    id: downloadItem.id,
    url: downloadItem.url,
    filename: downloadItem.filename,
    startTime: new Date().toISOString(),
    state: downloadItem.state,
    triggerInteraction: getCurrentInteractionId()
  };

  recordedDownloads.push(download);
});

chrome.downloads.onChanged.addListener((delta) => {
  if (!isRecording) return;

  const download = recordedDownloads.find(d => d.id === delta.id);
  if (download && delta.state) {
    download.state = delta.state.current;
  }
});
```

**Permissions needed:**
```json
{
  "permissions": ["downloads"]
}
```

---

### Change 5: Enhanced JSON Export

**Critical** - Current export is code strings, need structured JSON.

#### Implementation

Create `src/export/json-exporter.ts`:
```typescript
interface RecordingExport {
  metadata: {
    id: string;
    startTime: string;
    endTime: string;
    duration: number;
    baseUrl: string;
    browser: string;
    viewport: { width: number; height: number };
  };
  steps: Step[];
  har: HARLog;
  downloads: DownloadInfo[];
  summary: {
    totalSteps: number;
    interactions: number;
    navigations: number;
    networkRequests: number;
    downloads: number;
  };
}

interface Step {
  id: string;
  type: 'navigation' | 'click' | 'input' | 'scroll' | 'wait';
  timestamp: number;
  element?: ElementInfo;
  value?: string;
  beforeState?: StateCapture;
  afterState?: StateCapture;
}

interface StateCapture {
  url: string;
  html?: string; // Optional due to size
  htmlCompressed?: string;
  screenshot?: string;
  viewport: { width: number; height: number };
  scrollPosition: { x: number; y: number };
  networkActivity?: {
    pending: number;
    completed: number;
  };
}

interface ElementInfo {
  selectors: {
    primary: Selector;
    alternatives: Selector[];
  };
  tag: string;
  text?: string;
  attributes: Array<{ name: string; value: string }>;
  xpath?: string;
  cssPath?: string;
}

interface Selector {
  type: 'testid' | 'id' | 'aria' | 'role' | 'css' | 'xpath';
  value: string;
  role?: string;
  name?: string;
}

export class JSONExporter {
  private recording: RecordingExport;

  constructor(
    steps: Step[],
    harEntries: any[],
    downloads: DownloadInfo[],
    metadata: any
  ) {
    this.recording = {
      metadata: {
        id: metadata.id || generateId(),
        startTime: metadata.startTime,
        endTime: new Date().toISOString(),
        duration: Date.now() - new Date(metadata.startTime).getTime(),
        baseUrl: metadata.baseUrl || extractBaseUrl(steps),
        browser: navigator.userAgent,
        viewport: metadata.viewport
      },
      steps: steps,
      har: this.buildHAR(harEntries),
      downloads: downloads,
      summary: {
        totalSteps: steps.length,
        interactions: steps.filter(s => s.type !== 'navigation').length,
        navigations: steps.filter(s => s.type === 'navigation').length,
        networkRequests: harEntries.length,
        downloads: downloads.length
      }
    };
  }

  export(options: ExportOptions = {}): string {
    const data = this.recording;

    // Optional: Exclude large data
    if (options.excludeHTML) {
      data.steps.forEach(step => {
        if (step.beforeState) delete step.beforeState.html;
        if (step.afterState) delete step.afterState.html;
      });
    }

    if (options.excludeScreenshots) {
      data.steps.forEach(step => {
        if (step.beforeState) delete step.beforeState.screenshot;
        if (step.afterState) delete step.afterState.screenshot;
      });
    }

    return JSON.stringify(data, null, 2);
  }

  exportCompressed(): Blob {
    const json = this.export();
    const compressed = pako.gzip(json);
    return new Blob([compressed], { type: 'application/gzip' });
  }

  private buildHAR(entries: any[]): HARLog {
    return {
      log: {
        version: '1.2',
        creator: {
          name: 'DeploySentinel Recorder Enhanced',
          version: '2.0.0'
        },
        entries: entries
      }
    };
  }
}

interface ExportOptions {
  excludeHTML?: boolean;
  excludeScreenshots?: boolean;
  compressHTML?: boolean;
}
```

---

## Part 3: Potential Issues & Solutions

### Issue 1: Chrome DevTools Must Be Open for HAR

**Problem:** `chrome.devtools.network` API only works when DevTools is open.

**Impact:** Users must remember to open DevTools before recording.

**Solutions:**

**A. Document clearly in UI**
```typescript
// Add warning in popup
if (!isDevToolsOpen()) {
  showWarning(
    'Open DevTools (F12) to capture network requests. ' +
    'Recording will continue but network data will be missing.'
  );
}
```

**B. Detect DevTools state** (hacky but works)
```typescript
let isDevToolsOpen = false;

// Trick: console.log returns different value when DevTools open
const element = new Image();
Object.defineProperty(element, 'id', {
  get: function() {
    isDevToolsOpen = true;
    return 'devtools-detector';
  }
});

console.log(element);
```

**C. Alternative: Use declarativeNetRequest** (limited)
- Can see URLs, methods, status codes
- **Cannot** see request/response bodies
- Works without DevTools open

```typescript
// In background script
chrome.declarativeNetRequest.onRuleMatchedDebug.addListener((details) => {
  // Limited network info
  recordNetworkRequest({
    url: details.request.url,
    method: details.request.method,
    // No bodies available
  });
});
```

**Recommendation:** Use DevTools API, require DevTools open, add detection & warnings.

---

### Issue 2: Storage Size Explosion

**Problem:** Each interaction with HTML + 2 screenshots = ~5-10MB.

**Math:**
- 10 interactions × 8MB avg = 80MB
- 50 interactions = 400MB
- Chrome storage limits: 5MB (storage.local), unlimited (IndexedDB)

**Solution: Use IndexedDB**

Create `src/storage/indexed-db.ts`:
```typescript
class RecordingStorage {
  private db: IDBDatabase | null = null;

  async init() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open('RecorderDB', 1);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        this.db = request.result;
        resolve(this.db);
      };

      request.onupgradeneeded = (event) => {
        const db = (event.target as IDBOpenDBRequest).result;

        // Store recording metadata
        db.createObjectStore('recordings', { keyPath: 'id' });

        // Store individual steps (can be large)
        const steps = db.createObjectStore('steps', { keyPath: 'id' });
        steps.createIndex('recordingId', 'recordingId', { unique: false });

        // Store HAR entries
        const har = db.createObjectStore('harEntries', { keyPath: 'id' });
        har.createIndex('recordingId', 'recordingId', { unique: false });
      };
    });
  }

  async saveStep(recordingId: string, step: Step) {
    const transaction = this.db!.transaction(['steps'], 'readwrite');
    const store = transaction.objectStore('steps');

    await store.add({
      id: `${recordingId}-${step.id}`,
      recordingId,
      ...step
    });
  }

  async getRecording(recordingId: string): Promise<RecordingExport> {
    // Retrieve all pieces and assemble
    const recording = await this.getFromStore('recordings', recordingId);
    const steps = await this.getStepsByRecordingId(recordingId);
    const harEntries = await this.getHARByRecordingId(recordingId);

    return {
      ...recording,
      steps,
      har: { log: { entries: harEntries } }
    };
  }

  async cleanup(recordingId: string) {
    // Delete all data for a recording
    const transaction = this.db!.transaction(
      ['recordings', 'steps', 'harEntries'],
      'readwrite'
    );

    transaction.objectStore('recordings').delete(recordingId);

    // Delete steps
    const stepsIndex = transaction
      .objectStore('steps')
      .index('recordingId');
    const stepsRange = IDBKeyRange.only(recordingId);
    stepsIndex.openCursor(stepsRange).onsuccess = (event) => {
      const cursor = (event.target as IDBRequest).result;
      if (cursor) {
        cursor.delete();
        cursor.continue();
      }
    };

    // Similar for HAR entries
  }
}
```

**Compression Strategy:**
```typescript
// Only compress large HTML (> 100KB)
function smartCompress(html: string): string | CompressedData {
  if (html.length < 100000) {
    return html;
  }

  const compressed = pako.gzip(html);
  const base64 = btoa(String.fromCharCode(...compressed));

  return {
    compressed: true,
    data: base64,
    originalSize: html.length,
    compressedSize: base64.length
  };
}
```

---

### Issue 3: Performance Impact

**Problem:** Capturing full state on every interaction slows down recording.

**Measurements:**
- HTML capture: ~10-50ms
- Screenshot: ~100-200ms
- Combined: ~150-300ms per interaction

**Solutions:**

**A. Debouncing & Throttling**
```typescript
let captureQueue: Array<() => Promise<void>> = [];
let isProcessing = false;

async function queueCapture(fn: () => Promise<void>) {
  captureQueue.push(fn);

  if (!isProcessing) {
    isProcessing = true;
    while (captureQueue.length > 0) {
      const capture = captureQueue.shift()!;
      await capture();
      await sleep(50); // Rate limit
    }
    isProcessing = false;
  }
}
```

**B. Progressive Capture Levels**
```typescript
enum CaptureLevel {
  MINIMAL = 'minimal',     // Selectors only
  STANDARD = 'standard',   // + screenshots
  COMPLETE = 'complete'    // + HTML + HAR
}

interface CaptureStrategy {
  level: CaptureLevel;
  screenshotQuality: number;
  captureInterval: number; // Min ms between captures
}

const STRATEGIES: Record<CaptureLevel, CaptureStrategy> = {
  minimal: {
    level: CaptureLevel.MINIMAL,
    screenshotQuality: 0, // None
    captureInterval: 0
  },
  standard: {
    level: CaptureLevel.STANDARD,
    screenshotQuality: 70,
    captureInterval: 500
  },
  complete: {
    level: CaptureLevel.COMPLETE,
    screenshotQuality: 90,
    captureInterval: 1000
  }
};
```

**C. Web Workers for Processing**
```typescript
// Offload compression to worker
const compressionWorker = new Worker('compression-worker.js');

function compressInWorker(html: string): Promise<string> {
  return new Promise((resolve) => {
    compressionWorker.postMessage({ html });
    compressionWorker.onmessage = (e) => {
      resolve(e.data.compressed);
    };
  });
}
```

---

### Issue 4: Cross-Origin Iframes

**Problem:** Cannot access iframe content from different origins.

**Example:**
```html
<!-- Can access -->
<iframe src="/same-origin-page"></iframe>

<!-- Cannot access (SecurityError) -->
<iframe src="https://external-site.com/widget"></iframe>
```

**Solution:**
```typescript
function capturePageSnapshot(): PageSnapshot {
  let html = document.documentElement.outerHTML;

  // Try to capture iframe content
  const iframes = document.querySelectorAll('iframe');
  const iframeContents: Record<string, string> = {};

  iframes.forEach((iframe, index) => {
    try {
      const iframeDoc = iframe.contentDocument;
      if (iframeDoc) {
        iframeContents[`iframe-${index}`] = iframeDoc.documentElement.outerHTML;
      }
    } catch (e) {
      // Cross-origin, cannot access
      iframeContents[`iframe-${index}`] = `<cross-origin src="${iframe.src}" />`;
    }
  });

  return {
    url: window.location.href,
    html,
    iframes: iframeContents,
    timestamp: Date.now()
  };
}
```

---

### Issue 5: Dynamic Content & SPAs

**Problem:** Content changes after interaction without URL change.

**Example:** React/Vue apps where clicking doesn't navigate.

**Detection Strategy:**
```typescript
let lastDOMState = '';

function detectDOMChanges(): boolean {
  const currentState = document.body.innerHTML;
  const changed = currentState !== lastDOMState;
  lastDOMState = currentState;
  return changed;
}

// Use MutationObserver
const observer = new MutationObserver((mutations) => {
  if (isRecording && mutations.length > 0) {
    // Debounce to avoid too many captures
    debouncedStateCapture();
  }
});

observer.observe(document.body, {
  childList: true,
  subtree: true,
  attributes: true,
  characterData: true
});
```

**Smart Delay:**
```typescript
async function waitForNetworkIdle(timeout = 2000): Promise<void> {
  return new Promise((resolve) => {
    let timer: NodeJS.Timeout;
    let lastActivity = Date.now();

    const checkIdle = () => {
      const now = Date.now();
      if (now - lastActivity >= timeout) {
        resolve();
      } else {
        timer = setTimeout(checkIdle, 100);
      }
    };

    // Monitor fetch/XHR
    const originalFetch = window.fetch;
    window.fetch = async (...args) => {
      lastActivity = Date.now();
      return originalFetch(...args);
    };

    timer = setTimeout(checkIdle, 100);
  });
}
```

---

## Part 4: MVP Spike Approach

### Goal
Prove the concept works end-to-end in minimal time.

### Phase 1: Fork & Setup (Day 1, 4 hours)

**Steps:**
```bash
# Fork repository
git clone https://github.com/YourUsername/Recorder.git
cd Recorder

# Install dependencies
yarn install

# Create feature branch
git checkout -b feature/llm-export

# Test existing build
yarn run build-chrome
yarn run start-chrome
```

**Validate:** Extension loads in Chrome, can record basic interactions.

---

### Phase 2: Add Minimal HAR Capture (Day 2, 6 hours)

**Scope:** Just prove HAR capture works.

**Tasks:**
1. Create `src/devtools/devtools.html` and `src/devtools/devtools.js`
2. Update `manifest.chrome.json` with `devtools_page`
3. Add basic HAR listener
4. Store HAR entries in background script
5. Add console.log to verify capture

**Test:**
```typescript
// In devtools.js
chrome.devtools.network.onRequestFinished.addListener((request) => {
  console.log('Captured request:', request.request.url);
  chrome.runtime.sendMessage({
    type: 'HAR_ENTRY',
    data: {
      url: request.request.url,
      method: request.request.method,
      status: request.response.status
    }
  });
});
```

**Validate:**
- Open DevTools
- Start recording
- Navigate to a page
- See console logs for each request
- Check background script has stored entries

**Success Criteria:** See network requests logged to console.

---

### Phase 3: Add HTML Snapshot (Day 3, 4 hours)

**Scope:** Capture page HTML on click.

**Tasks:**
1. Modify content script to capture `document.documentElement.outerHTML`
2. Send to background script
3. Store in IndexedDB (add library)
4. Add simple UI to view captured HTML

**Test:**
```typescript
// In content script
document.addEventListener('click', () => {
  const html = document.documentElement.outerHTML;
  chrome.runtime.sendMessage({
    type: 'HTML_SNAPSHOT',
    data: {
      url: window.location.href,
      html: html,
      size: html.length,
      timestamp: Date.now()
    }
  });
}, true);
```

**Validate:**
- Click on page
- Check IndexedDB has HTML stored
- Verify HTML is complete (check for `<!DOCTYPE>`)

---

### Phase 4: Add Before/After Screenshots (Day 4, 6 hours)

**Scope:** Capture screenshot before and after click.

**Tasks:**
1. Add `chrome.tabs.captureVisibleTab` to background
2. Content script requests screenshot before click
3. Wait 1 second, capture after screenshot
4. Store both in IndexedDB

**Test:**
```typescript
// Simplified test
async function testScreenshotCapture() {
  console.log('Capturing before...');
  const before = await captureScreenshot();
  console.log('Before screenshot:', before.substring(0, 50));

  await sleep(1000);

  console.log('Capturing after...');
  const after = await captureScreenshot();
  console.log('After screenshot:', after.substring(0, 50));

  console.log('Difference:', before === after ? 'SAME' : 'DIFFERENT');
}
```

**Validate:**
- Screenshots are captured
- Data URLs are valid images
- Before and after are different (if page changed)

---

### Phase 5: JSON Export (Day 5, 4 hours)

**Scope:** Export all captured data as JSON.

**Tasks:**
1. Create `JSONExporter` class
2. Gather all data (interactions, HAR, HTML, screenshots)
3. Format as structured JSON
4. Add export button to UI
5. Test file download

**Test:**
```typescript
async function exportRecording() {
  const steps = await getRecordedSteps();
  const harEntries = await getHAREntries();

  const exporter = new JSONExporter(steps, harEntries);
  const json = exporter.export();

  // Verify structure
  const parsed = JSON.parse(json);
  console.assert(parsed.metadata, 'Missing metadata');
  console.assert(parsed.steps.length > 0, 'No steps');
  console.assert(parsed.har, 'Missing HAR');

  // Download
  const blob = new Blob([json], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  chrome.downloads.download({
    url: url,
    filename: `recording-${Date.now()}.json`
  });
}
```

**Validate:**
- JSON file downloads
- JSON is valid (can parse)
- Contains all expected fields
- File size is reasonable (< 50MB for simple recording)

---

### Phase 6: LLM Test (Day 6-7, 8 hours)

**Scope:** Feed exported JSON to Claude and generate Playwright test.

**Tasks:**
1. Record a simple 3-step workflow (login flow)
2. Export JSON
3. Create LLM prompt template
4. Send to Claude API
5. Validate generated Playwright code
6. Run generated test

**Test Workflow:**
```bash
# 1. Record workflow
- Navigate to demo login page
- Click email field
- Type email
- Click password field
- Type password
- Click submit
- Export JSON

# 2. Send to Claude
cat recording.json | jq '.steps' > steps.json

# Create prompt
cat << EOF > prompt.txt
Generate a Playwright test from this browser recording.

Use:
- Semantic locators (getByRole, getByLabel)
- Auto-waiting assertions
- TypeScript

Recording:
$(cat steps.json)

Generate complete test file.
EOF

# Send to Claude (or use API)
# Manually validate output looks correct

# 3. Test generated code
# Copy output to test.spec.ts
npx playwright test test.spec.ts
```

**Success Criteria:**
- Generated test is valid TypeScript
- Uses semantic locators
- Test runs without errors
- Test passes on the recorded site

---

## Part 5: Implementation Checklist

### MVP Checklist (Minimum for PoC)

- [ ] **Day 1: Setup**
  - [ ] Fork repository
  - [ ] Build and test existing extension
  - [ ] Create feature branch
  - [ ] Document current architecture

- [ ] **Day 2: HAR Capture**
  - [ ] Create devtools page
  - [ ] Update manifest
  - [ ] Add onRequestFinished listener
  - [ ] Store in background script
  - [ ] Test with DevTools open

- [ ] **Day 3: HTML Snapshot**
  - [ ] Add outerHTML capture
  - [ ] Set up IndexedDB
  - [ ] Store snapshots
  - [ ] Test retrieval

- [ ] **Day 4: Screenshots**
  - [ ] Add captureVisibleTab handler
  - [ ] Implement before/after capture
  - [ ] Add configurable delay
  - [ ] Store in IndexedDB

- [ ] **Day 5: JSON Export**
  - [ ] Create JSONExporter class
  - [ ] Gather all data sources
  - [ ] Format as structured JSON
  - [ ] Add download functionality
  - [ ] Test export size

- [ ] **Day 6-7: LLM Integration**
  - [ ] Record test workflow
  - [ ] Export JSON
  - [ ] Create prompt template
  - [ ] Send to Claude
  - [ ] Validate generated code
  - [ ] Run Playwright test

### Production Checklist (After MVP Success)

- [ ] **Error Handling**
  - [ ] Quota exceeded detection
  - [ ] Failed captures (graceful degradation)
  - [ ] Network errors
  - [ ] Invalid JSON recovery

- [ ] **UI/UX**
  - [ ] Recording status indicator
  - [ ] Progress bar for export
  - [ ] DevTools open warning
  - [ ] Storage usage display
  - [ ] Capture level selector

- [ ] **Performance**
  - [ ] Implement capture throttling
  - [ ] Add web worker for compression
  - [ ] Optimize IndexedDB queries
  - [ ] Lazy load large data

- [ ] **Testing**
  - [ ] Unit tests for core functions
  - [ ] E2E tests for recording flow
  - [ ] Export format validation
  - [ ] Browser compatibility (Chrome/Firefox)

- [ ] **Documentation**
  - [ ] README with setup instructions
  - [ ] Architecture documentation
  - [ ] API documentation for JSON format
  - [ ] LLM prompt examples
  - [ ] Troubleshooting guide

---

## Part 6: Practical Advice

### Development Tips

**1. Start with Chrome Only**
Don't worry about Firefox compatibility initially. Focus on Chrome, get it working, then adapt.

**2. Use TypeScript Strictly**
DeploySentinel already uses TypeScript. Don't cut corners—proper types will save debugging time.

**3. IndexedDB is Tricky**
Use a wrapper library like `idb` (by Jake Archibald):
```bash
yarn add idb
```

```typescript
import { openDB } from 'idb';

const db = await openDB('RecorderDB', 1, {
  upgrade(db) {
    db.createObjectStore('steps');
    db.createObjectStore('recordings');
  }
});

await db.put('steps', stepData, stepId);
const step = await db.get('steps', stepId);
```

**4. DevTools Detection**
Always show clear UI when DevTools isn't open:
```typescript
// In popup.tsx
{!isDevToolsOpen && (
  <Alert type="warning">
    Open DevTools (F12) to capture network requests
  </Alert>
)}
```

**5. Incremental Testing**
Test each piece in isolation before integration:
```typescript
// Test HAR capture alone
chrome.devtools.network.onRequestFinished.addListener((req) => {
  console.log('✓ HAR captured:', req.request.url);
});

// Test screenshot alone
chrome.tabs.captureVisibleTab(null, { format: 'png' }, (dataUrl) => {
  console.log('✓ Screenshot captured:', dataUrl.length, 'bytes');
});
```

---

### Debugging Tips

**1. Background Script Console**
```
chrome://extensions → Recorder → "Inspect views: background page"
```

**2. Content Script Console**
Regular DevTools console on the page.

**3. DevTools Script Console**
In the DevTools panel itself (right-click DevTools → Inspect).

**4. Storage Inspection**
```
chrome://extensions → Recorder → Storage → IndexedDB
```

**5. Message Tracing**
```typescript
// Add to background.ts
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  console.log('[BG] Message received:', message.type, message);
  // ... handle message
});

// Add to content.ts
console.log('[CONTENT] Sending message:', message.type);
chrome.runtime.sendMessage(message);
```

---

### Common Gotchas

**1. Message Size Limits**
Chrome limits messages to ~64MB, but practically ~1MB is safer.

**Solution:** Use IndexedDB for large data, send only IDs via messages.

**2. Async sendResponse**
Must return `true` to keep message channel open:
```typescript
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  doAsyncWork().then(result => sendResponse(result));
  return true; // ← CRITICAL
});
```

**3. Content Script Injection Timing**
Content scripts might run before page loads completely.

**Solution:**
```typescript
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
```

**4. Screenshot Timing**
Screenshots only capture visible tab area, not off-screen content.

**Solution:** Use `fullPage: true` option or scroll to capture multiple shots.

**5. Manifest V3 Service Workers**
Background scripts are now service workers—no persistent state.

**Solution:** Use storage APIs (storage.local, IndexedDB) for persistence.

---

### Testing Strategy

**Unit Tests (Jest)**
```typescript
// src/utils/selector.test.ts
describe('getElementSelector', () => {
  it('prioritizes data-testid', () => {
    const element = document.createElement('button');
    element.setAttribute('data-testid', 'submit-btn');

    const selector = getElementSelector(element);

    expect(selector.primary.type).toBe('testid');
    expect(selector.primary.value).toBe('submit-btn');
  });
});
```

**Integration Tests (Playwright)**
```typescript
// tests/e2e/recording.spec.ts
import { test, expect } from '@playwright/test';

test('records click interaction', async ({ page, context }) => {
  // Load extension
  const extensionId = await loadExtension(context);

  // Navigate to test page
  await page.goto('http://localhost:3000/test-page');

  // Start recording via extension
  await startRecording(extensionId);

  // Perform interaction
  await page.click('button#submit');

  // Stop recording
  await stopRecording(extensionId);

  // Verify data captured
  const recording = await getRecording(extensionId);
  expect(recording.steps).toHaveLength(1);
  expect(recording.steps[0].type).toBe('click');
});
```

**Manual Test Checklist**
```markdown
## Recording Test
- [ ] Extension loads without errors
- [ ] Start recording button works
- [ ] Click captured
- [ ] Input captured
- [ ] Navigation captured
- [ ] DevTools warning shows when closed
- [ ] Stop recording works
- [ ] Export downloads file
- [ ] File is valid JSON
- [ ] File size reasonable (< 50MB for 10 steps)

## Data Validation
- [ ] JSON has metadata section
- [ ] Steps array populated
- [ ] Each step has selectors
- [ ] HAR entries present (if DevTools open)
- [ ] Screenshots present
- [ ] HTML snapshots present
- [ ] Before/after states captured

## LLM Test
- [ ] JSON parses correctly
- [ ] Claude accepts prompt
- [ ] Generated test is valid TypeScript
- [ ] Generated test uses semantic locators
- [ ] Generated test runs
- [ ] Generated test passes
```

---

### Performance Benchmarks

Set targets and measure:

```typescript
// Add performance markers
performance.mark('capture-start');
const snapshot = await capturePageSnapshot();
performance.mark('capture-end');

const measure = performance.measure(
  'snapshot-capture',
  'capture-start',
  'capture-end'
);

console.log(`Snapshot took ${measure.duration.toFixed(2)}ms`);

// Track metrics
const metrics = {
  averageCaptureTime: 0,
  totalCaptures: 0,
  failedCaptures: 0,
  totalStorageUsed: 0
};
```

**Target Metrics:**
- Snapshot capture: < 100ms
- Screenshot capture: < 200ms
- Combined capture: < 300ms
- Export generation: < 2s for 20 steps
- Storage per step: < 5MB

---

### Risk Mitigation

**Risk 1: DevTools Requirement**
- **Mitigation:** Clear UI warnings, documentation, consider fallback to limited network data

**Risk 2: Storage Overflow**
- **Mitigation:** Storage quotas, auto-cleanup old recordings, compression

**Risk 3: Performance Impact**
- **Mitigation:** Configurable capture levels, throttling, web workers

**Risk 4: Cross-Origin Limitations**
- **Mitigation:** Document limitations, capture what's possible, note restrictions in export

**Risk 5: LLM Generation Quality**
- **Mitigation:** Multiple prompt templates, manual review step, iterative refinement

---

## Part 7: Recommended Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Browser Tab                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                  Content Script                       │  │
│  │                                                       │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌────────────┐  │  │
│  │  │   Event     │  │   Selector   │  │  Snapshot  │  │  │
│  │  │  Listeners  │→ │  Generator   │→ │  Capture   │  │  │
│  │  └─────────────┘  └──────────────┘  └────────────┘  │  │
│  │         │                                      │     │  │
│  │         └──────────── Messages ────────────────┘     │  │
│  └───────────────────────────────┬───────────────────────┘  │
└────────────────────────────────┬─┴──────────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │  Background Service    │
                    │                        │
                    │  ┌──────────────────┐  │
                    │  │  Message Router  │  │
                    │  └────────┬─────────┘  │
                    │           │            │
                    │  ┌────────▼─────────┐  │
                    │  │  State Manager   │  │
                    │  │  - Recording ID  │  │
                    │  │  - Config        │  │
                    │  └────────┬─────────┘  │
                    │           │            │
                    │  ┌────────▼─────────┐  │
                    │  │  Screenshot API  │  │
                    │  └──────────────────┘  │
                    │  ┌──────────────────┐  │
                    │  │  Download API    │  │
                    │  └──────────────────┘  │
                    └───────────┬────────────┘
                                │
                    ┌───────────▼────────────┐
                    │    IndexedDB           │
                    │                        │
                    │  ┌──────────────────┐  │
                    │  │   Recordings     │  │
                    │  └──────────────────┘  │
                    │  ┌──────────────────┐  │
                    │  │     Steps        │  │
                    │  └──────────────────┘  │
                    │  ┌──────────────────┐  │
                    │  │   HAR Entries    │  │
                    │  └──────────────────┘  │
                    └────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      DevTools Panel                         │
│  ┌───────────────────────────────────────────────────────┐  │
│  │               DevTools Script                         │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐ │  │
│  │  │  chrome.devtools.network.onRequestFinished      │ │  │
│  │  │                                                  │ │  │
│  │  │  → Capture HAR entries                          │ │  │
│  │  │  → Send to Background                           │ │  │
│  │  └─────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │    Export Pipeline     │
                    │                        │
                    │  ┌──────────────────┐  │
                    │  │  Data Collector  │  │
                    │  └────────┬─────────┘  │
                    │           │            │
                    │  ┌────────▼─────────┐  │
                    │  │  JSON Formatter  │  │
                    │  └────────┬─────────┘  │
                    │           │            │
                    │  ┌────────▼─────────┐  │
                    │  │   Compression    │  │
                    │  └────────┬─────────┘  │
                    │           │            │
                    │  ┌────────▼─────────┐  │
                    │  │  File Download   │  │
                    │  └──────────────────┘  │
                    └────────────────────────┘
```

---

## Summary & Next Steps

### What to Build First (MVP Priority)

1. **DevTools HAR Capture** (Highest value, validates approach)
2. **HTML Snapshot** (Easy win)
3. **Screenshot Before/After** (Core requirement)
4. **JSON Export** (Ties it together)
5. **LLM Integration Test** (Validates end-to-end)

### What to Defer (Post-MVP)

- File download tracking (nice-to-have)
- Advanced compression (optimize later)
- Web workers (if performance acceptable)
- Firefox support (Chrome first)
- UI polish (function over form for MVP)

### Estimated Timeline

- **Week 1:** MVP implementation (40 hours)
- **Week 2:** Testing, refinement, LLM integration (20 hours)
- **Week 3:** Polish, documentation, edge cases (20 hours)

**Total: 80 hours (~2-3 weeks full-time, 4-6 weeks part-time)**

### Go/No-Go Decision Points

**After Day 2 (HAR Capture):**
- **GO if:** HAR entries captured successfully with DevTools open
- **NO-GO if:** Can't get HAR data or data is insufficient

**After Day 5 (JSON Export):**
- **GO if:** JSON exports successfully, size < 100MB for simple workflow
- **NO-GO if:** Export too large, missing critical data, or unworkable format

**After Day 7 (LLM Test):**
- **GO if:** Generated Playwright test is reasonable quality (even if needs refinement)
- **NO-GO if:** Generated tests are unusable or require complete rewrite

### Success Metrics

**MVP Success =**
- ✅ Records 5-step workflow
- ✅ Exports JSON < 50MB
- ✅ JSON fed to Claude generates runnable Playwright test
- ✅ Test passes on recorded site (even if needs minor edits)

**Production Success =**
- ✅ Records 20-step workflow
- ✅ Exports JSON < 200MB
- ✅ 80%+ of generated tests run without edits
- ✅ Tests follow Playwright best practices (semantic locators, etc.)

---

## Conclusion

**You Should Do This If:**
- You're comfortable with TypeScript/React
- You have 2-3 weeks to dedicate
- You're OK with "DevTools must be open" limitation
- You want full control over the solution

**You Should NOT Do This If:**
- You need this working in < 1 week
- You're not comfortable with Chrome extension APIs
- You need Firefox/Safari support immediately
- You prefer using existing tools (stick with hybrid approach)

**My Recommendation:**
Build the MVP (Days 1-7) to validate the approach. If successful, continue to production. If blocked by fundamental issues (HAR capture doesn't work, export too large, LLM generation poor), fall back to the hybrid approach with existing tools.

The technical changes are feasible, the risks are manageable, and the MVP spike is well-defined. Good luck! 🚀
