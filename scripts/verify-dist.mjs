import fs from "node:fs";
import path from "node:path";

const projectRoot = process.cwd();
const distDir = path.join(projectRoot, "dist");
const indexHtmlPath = path.join(distDir, "index.html");

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

if (/<script\b/i.test(indexHtml)) {
  throw new Error("dist/index.html contains a <script> tag.");
}

const javascriptFiles = fs.existsSync(distDir) ? walkForJavaScriptFiles(distDir) : [];

if (javascriptFiles.length > 0) {
  throw new Error(`dist contains JavaScript assets: ${javascriptFiles.join(", ")}`);
}

console.log("Verified dist contains zero browser JavaScript.");
