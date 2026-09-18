// Optional: run in the page's DevTools console (F12 > Console; type
// "allow pasting" first if Firefox asks). Copies every large element that
// paints a background, gradient, shadow or blur to the clipboard.
(() => {
  const d = (el) => {
    let s = el.tagName.toLowerCase();
    if (el.id) s += "#" + el.id;
    for (const a of ["data-testid", "role", "aria-label"])
      if (el.hasAttribute(a)) s += `[${a}="${el.getAttribute(a)}"]`;
    const c = typeof el.className === "string" ? el.className.trim() : "";
    return c ? `${s} .${c.split(/\s+/).slice(0, 8).join(".")}` : s;
  };
  const out = [location.href];
  for (const el of document.querySelectorAll("body *")) {
    const r = el.getBoundingClientRect();
    if (r.width < 150 || r.height < 20) continue;
    for (const p of [null, "::before", "::after"]) {
      const cs = getComputedStyle(el, p);
      const bg = cs.backgroundColor, img = cs.backgroundImage, sh = cs.boxShadow;
      const hit = bg !== "rgba(0, 0, 0, 0)" || img.includes("gradient") ||
        cs.maskImage !== "none" || (sh !== "none" && !p) || cs.backdropFilter !== "none";
      if (hit) out.push(`${Math.round(r.width)}x${Math.round(r.height)}@${Math.round(r.top)} ${d(el)}${p ?? ""} bg=${bg} img=${img.slice(0, 80)} mask=${cs.maskImage.slice(0, 40)} shadow=${sh.slice(0, 60)} backdrop=${cs.backdropFilter} parent=${d(el.parentElement)}`);
    }
  }
  copy(out.join("\n"));
  return `${out.length - 1} painted elements copied`;
})();
