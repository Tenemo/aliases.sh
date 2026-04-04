import hljs from "highlight.js/lib/core";
import bash from "highlight.js/lib/languages/bash";
import "highlight.js/styles/a11y-dark.css";
import { initializeAliasesPage } from "./page";

hljs.registerLanguage("bash", bash);

const boot = (): void => {
  initializeAliasesPage(document, window, hljs);
};

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", boot, { once: true });
} else {
  boot();
}
