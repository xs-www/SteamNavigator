// @static-doc
// 作用：官网全站交互（导航抽屉、滚动状态、滚动揭示、图片灯箱、页脚年份、Hero 视差）。
//
// ## 契约与约束
// - 无依赖、无构建：直接以经典脚本加载，所有增强都必须可降级。
// - 内容默认可见；仅当 <html class="js"> 存在时才隐藏 `[data-reveal]`，避免无 JS 时白屏。
// - 尊重 `prefers-reduced-motion`：不接管动画，也不做滚动视差。
// - 不修改页面业务文案；年份只在 `[data-year]` 占位元素内更新。
// - 灯箱在首次点击时惰性创建，关闭后恢复触发元素焦点。
//
// ## 重点逻辑
// ### 导航
// - 移动端抽屉通过 body.nav-open + aria-expanded 同步；Esc、点击链接、窗口放大都会关闭。
// ### 灯箱
// - 由 `[data-lightbox]` 触发，图片地址取 data-lightbox；caption 取 data-caption 或图片 alt。
// - 使用原生 <dialog>，因此 Esc 与焦点管理由浏览器负责；点击遮罩也关闭。
// @end-static-doc

(() => {
  "use strict";

  const body = document.body;
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------------------------------------------------------------- header */
  const header = document.querySelector("[data-header]");
  const syncHeader = () => {
    if (!header) return;
    header.classList.toggle("is-scrolled", window.scrollY > 24);
  };
  syncHeader();
  window.addEventListener("scroll", syncHeader, { passive: true });

  /* ------------------------------------------------------------ mobile nav */
  const nav = document.getElementById("site-nav");
  const navToggle = document.querySelector("[data-nav-toggle]");
  const closeNav = (restoreFocus = false) => {
    if (!body.classList.contains("nav-open")) return;
    body.classList.remove("nav-open");
    if (navToggle) {
      navToggle.setAttribute("aria-expanded", "false");
      navToggle.setAttribute("aria-label", "打开菜单");
      if (restoreFocus) navToggle.focus();
    }
  };

  if (nav && navToggle) {
    navToggle.addEventListener("click", () => {
      const open = !body.classList.contains("nav-open");
      body.classList.toggle("nav-open", open);
      navToggle.setAttribute("aria-expanded", String(open));
      navToggle.setAttribute("aria-label", open ? "关闭菜单" : "打开菜单");
      if (open) {
        const first = nav.querySelector("a, button");
        if (first) first.focus({ preventScroll: true });
      }
    });

    nav.addEventListener("click", (event) => {
      if (event.target.closest("a")) closeNav();
    });

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && body.classList.contains("nav-open")) {
        closeNav(true);
      }
    });

    window.addEventListener("resize", () => {
      if (window.innerWidth > 860) closeNav();
    });
  }

  /* ------------------------------------------------------------- active nav */
  const page = body.dataset.page;
  if (page) {
    document.querySelectorAll("[data-nav]").forEach((link) => {
      if (link.dataset.nav === page) link.setAttribute("aria-current", "page");
    });
  }

  /* ----------------------------------------------------------- reveal once */
  const reveals = Array.from(document.querySelectorAll("[data-reveal]"));
  if (reveals.length) {
    if (reduceMotion || !("IntersectionObserver" in window)) {
      reveals.forEach((el) => el.classList.add("is-visible"));
    } else {
      const observer = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (!entry.isIntersecting) return;
            entry.target.classList.add("is-visible");
            observer.unobserve(entry.target);
          });
        },
        { rootMargin: "0px 0px -12% 0px", threshold: 0.08 }
      );
      reveals.forEach((el) => {
        const delay = el.dataset.revealDelay;
        if (delay) el.style.setProperty("--reveal-delay", `${delay}ms`);
        observer.observe(el);
      });
    }
  }

  /* --------------------------------------------------------------- lightbox */
  let dialog = null;
  let lastTrigger = null;

  const ensureDialog = () => {
    if (dialog) return dialog;
    dialog = document.createElement("dialog");
    dialog.className = "lightbox";
    dialog.setAttribute("aria-label", "放大的游戏画面");
    dialog.innerHTML =
      '<button class="lightbox__close" type="button" aria-label="关闭图片">' +
      '<svg class="icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18"/></svg>' +
      "</button>" +
      '<figure class="lightbox__figure"><img alt=""><figcaption class="lightbox__caption"></figcaption></figure>';
    document.body.appendChild(dialog);

    const close = () => dialog.close();
    dialog.querySelector(".lightbox__close").addEventListener("click", close);
    dialog.addEventListener("click", (event) => {
      if (event.target === dialog) close();
    });
    dialog.addEventListener("close", () => {
      dialog.querySelector("img").removeAttribute("src");
      if (lastTrigger) lastTrigger.focus({ preventScroll: true });
    });
    return dialog;
  };

  const openLightbox = (trigger) => {
    const image = trigger.querySelector("img");
    const src = trigger.dataset.lightbox || image?.dataset.full || image?.currentSrc || image?.src;
    if (!src) return;
    const caption =
      trigger.dataset.caption ||
      trigger.closest("figure")?.querySelector("figcaption")?.textContent?.trim() ||
      image?.alt ||
      "";
    const dlg = ensureDialog();
    const img = dlg.querySelector("img");
    img.src = src;
    img.alt = image?.alt || caption;
    dlg.querySelector(".lightbox__caption").textContent = caption;
    lastTrigger = trigger;
    if (!dlg.open) dlg.showModal();
  };

  document.addEventListener("click", (event) => {
    const trigger = event.target.closest("[data-lightbox]");
    if (!trigger) return;
    event.preventDefault();
    openLightbox(trigger);
  });

  /* ------------------------------------------------------------- hero drift */
  const heroImage = document.querySelector(".hero__media img");
  if (heroImage && !reduceMotion) {
    let frame = 0;
    let latest = 0;
    const update = () => {
      frame = 0;
      const shift = Math.min(latest, 700) * 0.045;
      heroImage.style.translate = `0 ${shift}px`;
    };
    window.addEventListener(
      "scroll",
      () => {
        latest = window.scrollY;
        if (frame) return;
        frame = window.requestAnimationFrame(update);
      },
      { passive: true }
    );
  }

  /* ------------------------------------------------------------------ year */
  const year = String(new Date().getFullYear());
  document.querySelectorAll("[data-year]").forEach((el) => {
    el.textContent = year;
  });
})();
