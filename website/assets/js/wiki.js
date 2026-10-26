// @static-doc
// 作用：渲染官网游戏百科：分类导航、实时搜索、条目卡片、结果计数与深链接。
//
// ## 契约与约束
// - 数据来自全局 `window.SN_WIKI_DATA`（由 tools/build-wiki-data.mjs 生成），页面不得硬编码条目。
// - 所有来自数据的文本一律用 textContent 写入，禁止拼接 innerHTML，避免内容注入。
// - 无数据 / 无结果 / 空搜索都必须有可见反馈，不能留空白页。
// - 分类筛选与搜索是交集关系；搜索词按空格拆分后要求全部命中（标题/描述/标签/数值）。
// - 深链接：`#cat-<id>` 选中分类，`#entry-<id>` 定位并高亮条目。
//
// ## 重点逻辑
// ### 渲染策略
// - 每次筛选重建条目卡片；条目数量在百级，重建成本远低于维护增量 diff 的复杂度。
// - 分类按钮只创建一次，之后只更新 aria-pressed 与计数。
// ### 深链接
// - 使用 history.replaceState 更新 hash，不污染浏览历史；条目定位后短暂高亮。
// @end-static-doc

(() => {
  "use strict";

  const data = window.SN_WIKI_DATA;
  const grid = document.getElementById("wiki-grid");
  const catsHost = document.getElementById("wiki-cats");
  const headingTitle = document.getElementById("wiki-heading-title");
  const headingIntro = document.getElementById("wiki-heading-intro");
  const countEl = document.getElementById("wiki-count");
  const searchWrap = document.querySelector(".wiki-search");
  const searchInput = document.getElementById("wiki-search");
  const clearButton = document.querySelector(".wiki-search__clear");
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  if (!grid || !catsHost || !searchInput) return;

  const renderFallback = (message) => {
    if (countEl) countEl.innerHTML = "";
    grid.replaceChildren();
    const wrap = document.createElement("div");
    wrap.className = "wiki-empty";
    const title = document.createElement("h3");
    title.textContent = "百科暂时无法载入";
    const p = document.createElement("p");
    p.textContent = message;
    wrap.append(title, p);
    grid.append(wrap);
  };

  if (!data || !Array.isArray(data.entries)) {
    renderFallback("百科数据缺失。请先运行 node website/tools/build-wiki-data.mjs 生成数据，再刷新本页。");
    return;
  }

  const categories = Array.isArray(data.categories) ? data.categories : [];
  const categoryById = new Map(categories.map((category) => [category.id, category]));
  const entries = data.entries.slice();

  const state = {
    category: "all",
    query: "",
  };

  const normalize = (value) => String(value ?? "").replace(/\s+/g, " ").trim().toLowerCase();

  const entryHaystack = new Map(
    entries.map((entry) => {
      const parts = [
        entry.title,
        entry.description,
        entry.kind,
        categoryById.get(entry.category)?.label,
        ...(entry.tags || []),
        ...(entry.stats || []).flat(),
      ];
      return [entry.id, normalize(parts.filter(Boolean).join(" "))];
    })
  );

  const makeIcon = (name) => {
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("class", "icon");
    svg.setAttribute("viewBox", "0 0 24 24");
    svg.setAttribute("aria-hidden", "true");
    const use = document.createElementNS("http://www.w3.org/2000/svg", "use");
    use.setAttribute("href", `#icon-${name || "book"}`);
    svg.append(use);
    return svg;
  };

  const makeText = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    node.textContent = text;
    return node;
  };

  /* --------------------------------------------------------------- category */
  const categoryButtons = new Map();

  const makeCategoryButton = (id, label, iconName, count) => {
    const li = document.createElement("li");
    const button = document.createElement("button");
    button.type = "button";
    button.dataset.category = id;
    button.setAttribute("aria-pressed", "false");

    const labelWrap = document.createElement("span");
    labelWrap.className = "wiki-cats__label";
    labelWrap.append(makeIcon(iconName), makeText("span", "", label));

    const badge = document.createElement("em");
    badge.dataset.count = id;
    badge.textContent = String(count);

    button.append(labelWrap, badge);
    button.addEventListener("click", () => {
      state.category = id;
      applyFilters({ updateHash: true });
    });

    li.append(button);
    categoryButtons.set(id, button);
    return li;
  };

  catsHost.append(makeCategoryButton("all", "全部", "book", entries.length));
  categories.forEach((category) => {
    const count = entries.filter((entry) => entry.category === category.id).length;
    catsHost.append(makeCategoryButton(category.id, category.label, category.icon, count));
  });

  /* ----------------------------------------------------------------- render */
  const filteredEntries = () => {
    const terms = normalize(state.query).split(" ").filter(Boolean);
    return entries.filter((entry) => {
      if (state.category !== "all" && entry.category !== state.category) return false;
      if (!terms.length) return true;
      const haystack = entryHaystack.get(entry.id) || "";
      return terms.every((term) => haystack.includes(term));
    });
  };

  const buildCard = (entry) => {
    const card = document.createElement("article");
    card.className = "wiki-card";
    card.id = `entry-${entry.id}`;
    card.dataset.entryId = entry.id;

    const top = document.createElement("div");
    top.className = "wiki-card__top";
    top.append(
      makeText("span", "wiki-card__kind", entry.kind || "条目"),
      makeText("span", "wiki-card__cat", categoryById.get(entry.category)?.label || "")
    );

    card.append(top, makeText("h3", "", entry.title));
    card.append(makeText("p", "wiki-card__desc", entry.description || "这页档案还没有写完。"));

    if (Array.isArray(entry.stats) && entry.stats.length) {
      const dl = document.createElement("dl");
      dl.className = "wiki-card__stats";
      entry.stats.forEach(([label, value]) => {
        if (!label || value === undefined || value === null || value === "") return;
        const row = document.createElement("div");
        row.append(makeText("dt", "", label), makeText("dd", "", String(value)));
        dl.append(row);
      });
      if (dl.childElementCount) card.append(dl);
    }

    if (Array.isArray(entry.tags) && entry.tags.length) {
      const tags = document.createElement("div");
      tags.className = "wiki-card__tags";
      entry.tags.forEach((tag) => tags.append(makeText("span", "wiki-tag", tag)));
      card.append(tags);
    }

    if (entry.link) {
      const link = document.createElement("a");
      link.className = "wiki-card__link";
      link.href = entry.link;
      link.append(makeText("span", "", "相关页面"), makeText("span", "", "→"));
      card.append(link);
    }

    return card;
  };

  const render = (list) => {
    const fragment = document.createDocumentFragment();
    if (!list.length) {
      const empty = document.createElement("div");
      empty.className = "wiki-empty";
      empty.append(makeIcon("search"));
      empty.append(makeText("h3", "", "没有找到匹配的记录"));
      empty.append(makeText("p", "", "换一个关键词，或回到全部条目重新翻阅。"));
      const reset = document.createElement("button");
      reset.type = "button";
      reset.className = "btn btn--small btn--ghost";
      reset.textContent = "清除筛选";
      reset.addEventListener("click", () => {
        state.category = "all";
        state.query = "";
        searchInput.value = "";
        searchWrap?.classList.remove("has-value");
        applyFilters({ updateHash: true });
        searchInput.focus();
      });
      empty.append(reset);
      fragment.append(empty);
      grid.replaceChildren(fragment);
      return;
    }
    list.forEach((entry) => fragment.append(buildCard(entry)));
    grid.replaceChildren(fragment);
  };

  const syncHeading = () => {
    const category = state.category === "all" ? null : categoryById.get(state.category);
    if (headingTitle) headingTitle.textContent = category ? category.heading : "全部条目";
    if (headingIntro) {
      headingIntro.textContent = category
        ? category.intro || ""
        : "按分类翻阅，或直接搜索港口、商品、船只与航线。";
    }
  };

  const syncCount = (total) => {
    if (!countEl) return;
    countEl.replaceChildren();
    countEl.append(document.createTextNode("共 "), makeText("b", "", String(total)), document.createTextNode(" 条记录"));
  };

  const syncCategoryButtons = () => {
    categoryButtons.forEach((button, id) => {
      button.setAttribute("aria-pressed", String(state.category === id));
    });
  };

  const applyFilters = ({ updateHash = false } = {}) => {
    syncCategoryButtons();
    syncHeading();
    const list = filteredEntries();
    render(list);
    syncCount(list.length);
    if (updateHash) {
      const hash = state.category === "all" ? "" : `#cat-${state.category}`;
      const url = `${window.location.pathname}${window.location.search}${hash}`;
      window.history.replaceState(null, "", url);
    }
  };

  /* --------------------------------------------------------------- searching */
  let searchTimer = 0;
  searchInput.addEventListener("input", () => {
    const value = searchInput.value;
    searchWrap?.classList.toggle("has-value", value.length > 0);
    window.clearTimeout(searchTimer);
    searchTimer = window.setTimeout(() => {
      state.query = value;
      applyFilters();
    }, 120);
  });

  searchInput.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      searchInput.value = "";
      state.query = "";
      searchWrap?.classList.remove("has-value");
      applyFilters();
    }
  });

  clearButton?.addEventListener("click", () => {
    searchInput.value = "";
    state.query = "";
    searchWrap?.classList.remove("has-value");
    applyFilters();
    searchInput.focus();
  });

  /* --------------------------------------------------------------- deep links */
  const focusEntry = (id) => {
    const category = categoryById.get(entries.find((entry) => entry.id === id)?.category);
    if (category) state.category = category.id;
    state.query = "";
    searchInput.value = "";
    searchWrap?.classList.remove("has-value");
    applyFilters();

    const card = document.getElementById(`entry-${id}`);
    if (!card) return;
    window.requestAnimationFrame(() => {
      card.scrollIntoView({ behavior: reduceMotion ? "auto" : "smooth", block: "center" });
      card.classList.add("is-target");
      window.setTimeout(() => card.classList.remove("is-target"), 2400);
    });
  };

  const applyHash = () => {
    const hash = window.location.hash.replace(/^#/, "");
    if (!hash) return;
    if (hash.startsWith("cat-")) {
      const id = hash.slice(4);
      if (id === "all" || categoryById.has(id)) {
        state.category = id;
        applyFilters();
      }
      return;
    }
    if (hash.startsWith("entry-")) {
      focusEntry(hash.slice(6));
    }
  };

  window.addEventListener("hashchange", applyHash);

  applyFilters();
  applyHash();
})();
