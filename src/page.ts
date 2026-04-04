export const ALIASES_CODE_SELECTOR = "pre code";

export type Highlighter = {
  highlightElement: (element: HTMLElement) => void;
};

export type WindowLike = {
  getSelection: () => Selection | null;
};

export const getAliasesCodeElement = (
  root: ParentNode = document
): HTMLElement | null => {
  return root.querySelector<HTMLElement>(ALIASES_CODE_SELECTOR);
};

export const getAliasesText = (root: ParentNode = document): string => {
  return getAliasesCodeElement(root)?.textContent ?? "";
};

export const highlightAliasesCodeBlocks = (
  root: ParentNode = document,
  highlighter?: Highlighter
): void => {
  if (!highlighter) {
    return;
  }

  const codeBlocks = root.querySelectorAll<HTMLElement>(ALIASES_CODE_SELECTOR);

  codeBlocks.forEach((block) => {
    highlighter.highlightElement(block);
  });
};

const isEditableElement = (element: Element | null): boolean => {
  if (!element) {
    return false;
  }

  const htmlElement = element as HTMLElement;

  return htmlElement.isContentEditable || element.matches("input, textarea");
};

export const selectAliasesCode = (
  doc: Document = document,
  win: WindowLike = window
): boolean => {
  const codeElement = getAliasesCodeElement(doc);
  const selection = win.getSelection();

  if (!codeElement || !selection) {
    return false;
  }

  const range = doc.createRange();
  range.selectNodeContents(codeElement);
  selection.removeAllRanges();
  selection.addRange(range);

  return true;
};

export const handleSelectAllShortcut = (
  event: KeyboardEvent,
  doc: Document = document,
  win: WindowLike = window
): void => {
  const isSelectAllShortcut =
    (event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "a";

  if (!isSelectAllShortcut || isEditableElement(doc.activeElement)) {
    return;
  }

  if (selectAliasesCode(doc, win)) {
    event.preventDefault();
  }
};

export const initializeAliasesPage = (
  doc: Document = document,
  win: WindowLike = window,
  highlighter?: Highlighter
): void => {
  highlightAliasesCodeBlocks(doc, highlighter);

  doc.addEventListener("keydown", (event) => {
    handleSelectAllShortcut(event, doc, win);
  });
};
