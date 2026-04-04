import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

const projectRoot = process.cwd();
const netlifyTomlPath = path.join(projectRoot, "netlify.toml");

describe("public SEO files", () => {
  it("defines the canonical home URL in robots and sitemap files", () => {
    const robots = fs.readFileSync(
      path.join(projectRoot, "public", "robots.txt"),
      "utf-8"
    );
    const sitemap = fs.readFileSync(
      path.join(projectRoot, "public", "sitemap.xml"),
      "utf-8"
    );

    expect(robots).toContain("User-agent: *");
    expect(robots).toContain("Allow: /");
    expect(robots).toContain("Sitemap: https://aliases.sh/sitemap.xml");
    expect(sitemap).toContain("<loc>https://aliases.sh/</loc>");
  });

  it("provides a stable OG image file at the public path", () => {
    const ogImagePath = path.join(projectRoot, "public", "og", "aliases-sh.png");

    expect(fs.existsSync(ogImagePath)).toBe(true);
  });

  it("uses netlify.toml for the host redirect instead of a public _redirects file", () => {
    const netlifyToml = fs.readFileSync(netlifyTomlPath, "utf-8");

    expect(netlifyToml).toContain('publish = "dist"');
    expect(netlifyToml).toContain('from = "https://www.aliases.sh/*"');
    expect(netlifyToml).toContain('to = "https://aliases.sh/:splat"');
    expect(netlifyToml).toContain("status = 301");
    expect(netlifyToml).toContain("force = true");
    expect(fs.existsSync(path.join(projectRoot, "public", "_redirects"))).toBe(false);
  });
});
