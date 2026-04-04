import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

const projectRoot = process.cwd();
const netlifyTomlPath = path.join(projectRoot, "netlify.toml");
const canonicalUrl = "https://aliases.sh/";

describe("static SEO files", () => {
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
    expect(robots).toContain(`Sitemap: ${canonicalUrl}sitemap.xml`);
    expect(sitemap).toContain(`<loc>${canonicalUrl}</loc>`);
  });

  it("provides a stable OG image file at the public path", () => {
    const ogImagePath = path.join(projectRoot, "public", "og", "aliases-sh.png");

    expect(fs.existsSync(ogImagePath)).toBe(true);
  });

  it("ships a branded web manifest instead of placeholder values", () => {
    const manifest = JSON.parse(
      fs.readFileSync(path.join(projectRoot, "favicon", "site.webmanifest"), "utf-8")
    ) as {
      background_color: string;
      display: string;
      name: string;
      short_name: string;
      theme_color: string;
    };

    expect(manifest.name).toBe("aliases.sh");
    expect(manifest.short_name).toBe("aliases.sh");
    expect(manifest.theme_color).toBe("#ffffff");
    expect(manifest.background_color).toBe("#ffffff");
    expect(manifest.display).toBe("standalone");
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
