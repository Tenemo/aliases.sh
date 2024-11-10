import hljs from "highlight.js";
import "highlight.js/styles/a11y-dark.css";

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("pre code").forEach((block) => {
    hljs.highlightElement(block);
  });
});
