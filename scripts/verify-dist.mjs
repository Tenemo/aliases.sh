import fs from "node:fs";
import path from "node:path";
import { JSDOM } from "jsdom";

const projectRoot = process.cwd();
const distDir = path.join(projectRoot, "dist");
const indexHtmlPath = path.join(distDir, "index.html");
const canonicalUrl = "https://aliases.sh/";
const ogImageUrl = "https://aliases.sh/og/aliases-sh.png";
const robotsPath = path.join(distDir, "robots.txt");
const sitemapPath = path.join(distDir, "sitemap.xml");
const ogImagePath = path.join(distDir, "og", "aliases-sh.png");
const redirectsPath = path.join(distDir, "_redirects");

const walkForJavaScriptFiles = (directoryPath) => {
  const entries = fs.readdirSync(directoryPath, { withFileTypes: true });
  const javascriptFiles = [];

  for (const entry of entries) {
    const fullPath = path.join(directoryPath, entry.name);

    if (entry.isDirectory()) {
      javascriptFiles.push(...walkForJavaScriptFiles(fullPath));
      continue;
    }

    if (entry.isFile() && fullPath.toLowerCase().endsWith(".js")) {
      javascriptFiles.push(path.relative(projectRoot, fullPath));
    }
  }

  return javascriptFiles;
};

if (!fs.existsSync(indexHtmlPath)) {
  throw new Error(`Missing build artifact: ${path.relative(projectRoot, indexHtmlPath)}`);
}

const indexHtml = fs.readFileSync(indexHtmlPath, "utf-8");
const dom = new JSDOM(indexHtml, {
  url: canonicalUrl,
});
const scriptElements = [...dom.window.document.querySelectorAll("script")];
const executableScripts = scriptElements.filter((scriptElement) => {
  const type = (scriptElement.getAttribute("type") ?? "").trim().toLowerCase();
  return type === "" || type === "module" || type === "text/javascript" || type === "application/javascript";
});

if (executableScripts.length > 0) {
  throw new Error("dist/index.html contains an executable <script> tag.");
}

const javascriptFiles = fs.existsSync(distDir) ? walkForJavaScriptFiles(distDir) : [];

if (javascriptFiles.length > 0) {
  throw new Error(`dist contains JavaScript assets: ${javascriptFiles.join(", ")}`);
}

const canonicalLinks = dom.window.document.querySelectorAll('link[rel="canonical"]');

if (canonicalLinks.length !== 1) {
  throw new Error(`Expected exactly one canonical link, found ${canonicalLinks.length}.`);
}

if (canonicalLinks[0].getAttribute("href") !== canonicalUrl) {
  throw new Error("Canonical URL does not match https://aliases.sh/.");
}

const structuredDataScripts = dom.window.document.querySelectorAll(
  'script[type="application/ld+json"]'
);

if (structuredDataScripts.length !== 1) {
  throw new Error(
    `Expected exactly one WebSite structured data script, found ${structuredDataScripts.length}.`
  );
}

const structuredData = JSON.parse(structuredDataScripts[0].textContent ?? "");

if (structuredData["@type"] !== "WebSite" || structuredData.url !== canonicalUrl) {
  throw new Error("WebSite structured data is missing or invalid.");
}

const ogImage = dom.window.document.querySelector('meta[property="og:image"]');

if (ogImage?.getAttribute("content") !== ogImageUrl) {
  throw new Error("Open Graph image URL is missing or invalid.");
}

const twitterCard = dom.window.document.querySelector('meta[name="twitter:card"]');

if (twitterCard?.getAttribute("content") !== "summary_large_image") {
  throw new Error("Twitter card metadata is missing or invalid.");
}

if (!fs.existsSync(robotsPath)) {
  throw new Error("dist/robots.txt is missing.");
}

if (!fs.existsSync(sitemapPath)) {
  throw new Error("dist/sitemap.xml is missing.");
}

if (!fs.existsSync(ogImagePath)) {
  throw new Error("dist/og/aliases-sh.png is missing.");
}

if (fs.existsSync(redirectsPath)) {
  throw new Error("dist/_redirects should not exist when Netlify redirects live in netlify.toml.");
}

const robots = fs.readFileSync(robotsPath, "utf-8");
const sitemap = fs.readFileSync(sitemapPath, "utf-8");

if (!robots.includes("Sitemap: https://aliases.sh/sitemap.xml")) {
  throw new Error("robots.txt is missing the sitemap directive.");
}

if (!sitemap.includes("<loc>https://aliases.sh/</loc>")) {
  throw new Error("sitemap.xml is missing the canonical home URL.");
}

console.log("Verified dist contains zero browser JavaScript and the expected SEO metadata.");
