/* v3 — paints Identity .cCenterPanel; loaded via login customHeadTags */
(function () {
  function paint(el) {
    if (!el) return;
    el.style.setProperty("background-color", "{{HEADER_RGBA}}", "important");
    el.style.setProperty("background-image", "none", "important");
    el.style.setProperty("box-shadow", "none", "important");
    el.style.setProperty("border", "1px solid rgba(255,255,255,0.12)", "important");
  }
  function injectCss() {
    if (document.getElementById("partner-login-css-link")) {
      return;
    }
    var link = document.createElement("link");
    link.id = "partner-login-css-link";
    link.rel = "stylesheet";
    link.href = "/sfsites/c/resource/RLM_PartnerLogin";
    (document.head || document.documentElement).appendChild(link);
  }
  function go() {
    injectCss();
    var nodes = document.querySelectorAll(".cCenterPanel");
    var i = 0;
    while (nodes[i]) {
      paint(nodes[i]);
      i += 1;
    }
  }
  go();
  document.addEventListener("DOMContentLoaded", go);
  if (document.documentElement) {
    new MutationObserver(go).observe(document.documentElement, {
      childList: true,
      subtree: true
    });
  }
})();
