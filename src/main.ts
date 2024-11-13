import hljs from "highlight.js/lib/core";
import bash from "highlight.js/lib/languages/bash";
import "highlight.js/styles/a11y-dark.css";

hljs.registerLanguage("bash", bash);

document.addEventListener("DOMContentLoaded", () => {
  const codeBlocks: NodeListOf<HTMLElement> =
    document.querySelectorAll("pre code");

  codeBlocks.forEach((block) => {
    hljs.highlightElement(block);
  });
});
