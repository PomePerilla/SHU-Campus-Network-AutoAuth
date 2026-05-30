import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

function loadPlaywright() {
  try {
    return require("playwright-core");
  } catch {
    return require("playwright");
  }
}

function readArg(name, fallback = "") {
  const index = process.argv.indexOf(name);
  if (index < 0 || index + 1 >= process.argv.length) {
    return fallback;
  }

  return process.argv[index + 1];
}

function toInt(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function summarizeUrl(value) {
  try {
    const url = new URL(value);
    return `${url.host}${url.pathname}`;
  } catch {
    return "<invalid-url>";
  }
}

function validatePortalUrl(value) {
  const expectedKeys = [
    "wlanuserip",
    "wlanacname",
    "nasip",
    "mac",
    "nasid",
    "vid",
    "port",
    "nasportid",
  ];

  try {
    const url = new URL(value);
    const keys = expectedKeys.filter((key) => url.searchParams.has(key));
    const path = url.pathname.toLowerCase();
    const isLoginUrl =
      url.hostname === "10.10.9.9" &&
      path === "/eportal/index.jsp" &&
      url.search.length > 1 &&
      keys.length >= 2;
    const isAuthenticated =
      url.hostname === "10.10.9.9" &&
      (path === "/eportal/success.jsp" || path === "/eportal/modify_pwd.jsp");

    return {
      ok: isLoginUrl,
      state: isLoginUrl
        ? "login-url-detected"
        : isAuthenticated
          ? "already-authenticated"
          : "not-detected",
      host: url.hostname,
      path: url.pathname,
      queryLength: Math.max(url.search.length - 1, 0),
      matchedKeys: keys,
      matchedKeyCount: keys.length,
      safeUrl: summarizeUrl(value),
    };
  } catch {
    return {
      ok: false,
      state: "invalid-url",
      host: "",
      path: "",
      queryLength: 0,
      matchedKeys: [],
      matchedKeyCount: 0,
      safeUrl: "<invalid-url>",
    };
  }
}

function isAllowedRequestUrl(value) {
  try {
    const url = new URL(value);
    return url.hostname === "10.10.9.9" || url.hostname === "123.123.123.123";
  } catch {
    return false;
  }
}

function detectExternalCaptiveCheck(value) {
  try {
    const url = new URL(value);
    return url.hostname.toLowerCase().includes("msftconnecttest.com");
  } catch {
    return false;
  }
}

async function main() {
  const startUrl = readArg("--url", "http://10.10.9.9/");
  const waitMs = toInt(readArg("--wait-ms", "5000"), 5000);
  const timeoutMs = toInt(readArg("--timeout-ms", "15000"), 15000);
  const channel = readArg("--channel", "msedge");
  const headless = !process.argv.includes("--headed");
  const requireChannel = process.argv.includes("--require-channel");

  const { chromium } = loadPlaywright();
  let browser;
  let page;
  let launchMode = channel;
  let navigationError = "";
  let title = "";
  let finalUrl = "";
  let validation = validatePortalUrl("");

  try {
    const launchOptions = {
      headless,
      args: [
        "--disable-background-networking",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-sync",
        "--disable-component-update",
        "--disable-features=Translate,MediaRouter,OptimizationHints",
      ],
    };

    try {
      browser = await chromium.launch({ ...launchOptions, channel });
    } catch (error) {
      if (requireChannel) {
        throw error;
      }

      launchMode = "bundled-chromium";
      browser = await chromium.launch(launchOptions);
    }

    page = await browser.newPage({
      userAgent:
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
      locale: "zh-Hans",
    });

    await page.route("**/*", async (route) => {
      const requestUrl = route.request().url();
      if (isAllowedRequestUrl(requestUrl)) {
        await route.continue();
        return;
      }

      await route.abort("blockedbyclient");
    });

    try {
      await page.goto(startUrl, {
        waitUntil: "domcontentloaded",
        timeout: timeoutMs,
      });
    } catch (error) {
      navigationError = error instanceof Error ? error.message : String(error);
    }

    await page.waitForTimeout(waitMs);

    try {
      title = await page.title();
    } catch {
      title = "";
    }

    finalUrl = page.url();
    validation = validatePortalUrl(finalUrl);
    if (!validation.ok && detectExternalCaptiveCheck(finalUrl)) {
      validation.state = "external-captive-check";
    }
  } finally {
    if (browser) {
      await browser.close().catch(() => {});
    }
  }

  const result = {
    success: validation.ok,
    state: validation.state,
    launchMode,
    startUrl,
    finalUrl,
    safeUrl: validation.safeUrl,
    title,
    waitMs,
    timeoutMs,
    navigationError,
    host: validation.host,
    path: validation.path,
    queryLength: validation.queryLength,
    matchedKeys: validation.matchedKeys,
    matchedKeyCount: validation.matchedKeyCount,
  };

  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  process.exit(validation.ok || validation.state === "already-authenticated" ? 0 : 1);
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stdout.write(
    `${JSON.stringify(
      {
        success: false,
        error: message,
      },
      null,
      2,
    )}\n`,
  );
  process.exit(1);
});
