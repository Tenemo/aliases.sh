import fs from "fs";
import path from "path";

const escapeHtml = (content) => {
  return content
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
};

export default {
  server: {
    open: true,
  },
  plugins: [
    {
      name: "inject-aliases",
      transformIndexHtml(html) {
        const aliasesPath = path.resolve(__dirname, "aliases.sh");
        const aliasesContent = fs.readFileSync(aliasesPath, "utf-8");
        const escapedContent = escapeHtml(aliasesContent);
        return html.replace(
          '<pre><code class="language-bash"></code></pre>',
          `<pre><code class="language-bash">${escapedContent}</code></pre>`
        );
      },
    },
  ],
};
