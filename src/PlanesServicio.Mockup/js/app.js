/*
 * Configurador de Servicios y Planes — mockup estático (HTML + JS puro).
 * Persistencia: localStorage (simula el "archivo plano"), con exportar/importar
 * a un .json real. Reemplazar por llamadas a API/BD cuando exista backend.
 */
(function () {
  "use strict";

  var STORAGE_KEY = "psm_config_v1";
  var AUTH_KEY = "psm_auth_v1";

  // ---------------------------------------------------------------------
  // Datos semilla (se usan solo la primera vez, si no hay nada guardado)
  // ---------------------------------------------------------------------
  var SEED_CONFIG = {
    servicios: [
      {
        id: "srv-tv",
        nombre: "TV",
        icono: "📺",
        planes: [
          {
            id: "p1", nombre: "Básico", precio: 100, heredaDeInferior: false,
            caracteristicas: [
              { id: "c1", texto: "Canales nacionales" },
              { id: "c2", texto: "1 pantalla simultánea" },
              { id: "c3", texto: "Calidad SD" }
            ]
          },
          {
            id: "p2", nombre: "Estándar", precio: 150, heredaDeInferior: true,
            caracteristicas: [
              { id: "c4", texto: "Canales de cable" },
              { id: "c5", texto: "2 pantallas simultáneas" },
              { id: "c6", texto: "Calidad HD" }
            ]
          },
          {
            id: "p3", nombre: "Premium", precio: 200, heredaDeInferior: true,
            caracteristicas: [
              { id: "c7", texto: "HBO Max" },
              { id: "c8", texto: "Disney+" },
              { id: "c9", texto: "4 pantallas simultáneas" },
              { id: "c10", texto: "Calidad 4K" }
            ]
          }
        ]
      },
      {
        id: "srv-hotel",
        nombre: "Hotel",
        icono: "🏨",
        planes: [
          {
            id: "p4", nombre: "Básica", precio: 80, heredaDeInferior: false,
            caracteristicas: [
              { id: "c11", texto: "Cama queen" },
              { id: "c12", texto: "WiFi" }
            ]
          },
          {
            id: "p5", nombre: "Estándar", precio: 130, heredaDeInferior: true,
            caracteristicas: [
              { id: "c13", texto: "Desayuno incluido" },
              { id: "c14", texto: "Vista a la ciudad" }
            ]
          },
          {
            id: "p6", nombre: "Suite", precio: 220, heredaDeInferior: true,
            caracteristicas: [
              { id: "c15", texto: "Jacuzzi" },
              { id: "c16", texto: "Sala de estar" },
              { id: "c17", texto: "Servicio a la habitación 24h" }
            ]
          }
        ]
      },
      {
        id: "srv-comida",
        nombre: "Comida",
        icono: "🍽️",
        planes: [
          {
            id: "p7", nombre: "Básico", precio: 15, heredaDeInferior: false,
            caracteristicas: [{ id: "c18", texto: "Menú del día" }]
          },
          {
            id: "p8", nombre: "Estándar", precio: 25, heredaDeInferior: true,
            caracteristicas: [
              { id: "c19", texto: "Bebida incluida" },
              { id: "c20", texto: "Postre" }
            ]
          },
          {
            id: "p9", nombre: "Premium", precio: 40, heredaDeInferior: true,
            caracteristicas: [
              { id: "c21", texto: "Menú gourmet" },
              { id: "c22", texto: "Maridaje de vinos" }
            ]
          }
        ]
      }
    ]
  };

  var EMOJI_OPTIONS = ["📺", "🏨", "🍽️", "🎮", "📶", "🚗", "🏋️", "🎓", "🩺", "🎵", "☎️", "🧹",
    "💻", "🚿", "🅿️", "🐾", "✈️", "🛡️"];

  // ---------------------------------------------------------------------
  // Estado
  // ---------------------------------------------------------------------
  var state = loadState();
  var currentServicioId = state.servicios.length ? state.servicios[0].id : null;
  var pendingPayment = null; // { servicioId, planId }
  var draggedPlanId = null;
  var draggedFeature = null; // { planId, featureId }
  var saveTimer = null;

  function uid(prefix) {
    return prefix + "_" + Math.random().toString(36).slice(2, 9);
  }

  function loadState() {
    var raw = null;
    try { raw = localStorage.getItem(STORAGE_KEY); } catch (e) { /* storage no disponible */ }
    if (raw) {
      try {
        var parsed = JSON.parse(raw);
        if (parsed && Array.isArray(parsed.servicios)) return parsed;
      } catch (e) { console.warn("Configuración guardada corrupta, se usa la semilla por defecto."); }
    }
    return JSON.parse(JSON.stringify(SEED_CONFIG));
  }

  function saveState() {
    var status = document.getElementById("saveStatus");
    if (status) status.textContent = "Guardando…";
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); } catch (e) { /* ignorar */ }
    clearTimeout(saveTimer);
    saveTimer = setTimeout(function () {
      if (status) status.textContent = "Guardado";
    }, 250);
  }

  function getCurrentUser() {
    try {
      var raw = localStorage.getItem(AUTH_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch (e) { return null; }
  }

  function setCurrentUser(user) {
    try { localStorage.setItem(AUTH_KEY, JSON.stringify(user)); } catch (e) { /* ignorar */ }
  }

  function logout() {
    try { localStorage.removeItem(AUTH_KEY); } catch (e) { /* ignorar */ }
    renderAuthArea();
  }

  function getServicio(id) {
    var i;
    for (i = 0; i < state.servicios.length; i++) {
      if (state.servicios[i].id === id) return state.servicios[i];
    }
    return null;
  }

  function money(n) {
    var v = Number(n) || 0;
    return "$" + v.toLocaleString("es", { maximumFractionDigits: 2 });
  }

  // ---------------------------------------------------------------------
  // Render: barra de autenticación
  // ---------------------------------------------------------------------
  function renderAuthArea() {
    var area = document.getElementById("authArea");
    var user = getCurrentUser();
    area.innerHTML = "";
    if (user) {
      var wrap = document.createElement("div");
      wrap.className = "auth-user";
      var avatar = document.createElement("span");
      avatar.className = "auth-avatar";
      avatar.textContent = (user.email || "?").charAt(0).toUpperCase();
      var name = document.createElement("span");
      name.textContent = user.email;
      var out = document.createElement("button");
      out.className = "btn-ghost";
      out.textContent = "Cerrar sesión";
      out.style.padding = "2px 8px";
      out.addEventListener("click", logout);
      wrap.appendChild(avatar);
      wrap.appendChild(name);
      area.appendChild(wrap);
      area.appendChild(out);
    } else {
      var btn = document.createElement("button");
      btn.className = "btn-ghost";
      btn.textContent = "Iniciar sesión";
      btn.addEventListener("click", function () { openLoginModal(); });
      area.appendChild(btn);
    }
  }

  // ---------------------------------------------------------------------
  // Render: sidebar de servicios
  // ---------------------------------------------------------------------
  function renderSidebar() {
    var list = document.getElementById("servicioList");
    list.innerHTML = "";
    state.servicios.forEach(function (servicio) {
      var li = document.createElement("li");
      li.className = "servicio-item" + (servicio.id === currentServicioId ? " active" : "");
      li.draggable = true;
      li.dataset.servicioId = servicio.id;

      var icon = document.createElement("span");
      icon.className = "icon";
      icon.textContent = servicio.icono || "🧩";

      var name = document.createElement("span");
      name.className = "name";
      name.textContent = servicio.nombre || "Sin nombre";

      var del = document.createElement("button");
      del.className = "del-servicio";
      del.textContent = "✕";
      del.title = "Eliminar servicio";
      del.addEventListener("click", function (ev) {
        ev.stopPropagation();
        deleteServicio(servicio.id);
      });

      li.appendChild(icon);
      li.appendChild(name);
      li.appendChild(del);

      li.addEventListener("click", function () {
        currentServicioId = servicio.id;
        renderSidebar();
        renderBoard();
      });

      li.addEventListener("dragstart", function () {
        draggedPlanId = null; // no confundir con drag de features
        li.dataset.dragging = "1";
      });
      li.addEventListener("dragover", function (ev) {
        ev.preventDefault();
        li.classList.add("drag-over");
      });
      li.addEventListener("dragleave", function () { li.classList.remove("drag-over"); });
      li.addEventListener("drop", function (ev) {
        ev.preventDefault();
        li.classList.remove("drag-over");
        var draggingEl = list.querySelector('[data-dragging="1"]');
        if (!draggingEl || draggingEl === li) return;
        var fromId = draggingEl.dataset.servicioId;
        reorderServicios(fromId, servicio.id);
      });
      li.addEventListener("dragend", function () { delete li.dataset.dragging; });

      list.appendChild(li);
    });
  }

  function reorderServicios(fromId, toId) {
    var arr = state.servicios;
    var fromIdx = arr.findIndex(function (s) { return s.id === fromId; });
    var toIdx = arr.findIndex(function (s) { return s.id === toId; });
    if (fromIdx === -1 || toIdx === -1 || fromIdx === toIdx) return;
    var item = arr.splice(fromIdx, 1)[0];
    arr.splice(toIdx, 0, item);
    saveState();
    renderSidebar();
  }

  function addServicio() {
    var servicio = {
      id: uid("srv"),
      nombre: "Nuevo servicio",
      icono: "🧩",
      planes: [
        { id: uid("plan"), nombre: "Básico", precio: 0, heredaDeInferior: false, caracteristicas: [] },
        { id: uid("plan"), nombre: "Estándar", precio: 0, heredaDeInferior: true, caracteristicas: [] },
        { id: uid("plan"), nombre: "Premium", precio: 0, heredaDeInferior: true, caracteristicas: [] }
      ]
    };
    state.servicios.push(servicio);
    currentServicioId = servicio.id;
    saveState();
    renderSidebar();
    renderBoard();
  }

  function deleteServicio(id) {
    var servicio = getServicio(id);
    if (!servicio) return;
    if (!confirm('¿Eliminar el servicio "' + servicio.nombre + '" y todos sus planes?')) return;
    state.servicios = state.servicios.filter(function (s) { return s.id !== id; });
    if (currentServicioId === id) {
      currentServicioId = state.servicios.length ? state.servicios[0].id : null;
    }
    saveState();
    renderSidebar();
    renderBoard();
  }

  // ---------------------------------------------------------------------
  // Render: tablero (columnas = planes, tarjetas = características)
  // ---------------------------------------------------------------------
  function renderBoardHeader() {
    var header = document.getElementById("boardHeader");
    header.innerHTML = "";
    var servicio = getServicio(currentServicioId);
    if (!servicio) return;

    var iconBtn = document.createElement("button");
    iconBtn.className = "servicio-icon-btn";
    iconBtn.textContent = servicio.icono || "🧩";
    iconBtn.title = "Cambiar ícono";
    iconBtn.addEventListener("click", function (ev) {
      ev.stopPropagation();
      toggleEmojiPicker(iconBtn, servicio);
    });

    var titleInput = document.createElement("input");
    titleInput.className = "servicio-title-input";
    titleInput.value = servicio.nombre;
    titleInput.addEventListener("input", function () { servicio.nombre = titleInput.value; });
    titleInput.addEventListener("blur", function () { saveState(); renderSidebar(); });

    var delBtn = document.createElement("button");
    delBtn.className = "btn-danger";
    delBtn.textContent = "Eliminar servicio";
    delBtn.addEventListener("click", function () { deleteServicio(servicio.id); });

    header.appendChild(iconBtn);
    header.appendChild(titleInput);
    header.appendChild(delBtn);
  }

  function toggleEmojiPicker(anchorBtn, servicio) {
    var existing = anchorBtn.querySelector(".emoji-picker");
    if (existing) { existing.remove(); return; }
    document.querySelectorAll(".emoji-picker").forEach(function (p) { p.remove(); });

    var picker = document.createElement("div");
    picker.className = "emoji-picker";
    EMOJI_OPTIONS.forEach(function (em) {
      var b = document.createElement("button");
      b.type = "button";
      b.textContent = em;
      b.addEventListener("click", function (ev) {
        ev.stopPropagation();
        servicio.icono = em;
        saveState();
        renderSidebar();
        renderBoardHeader();
      });
      picker.appendChild(b);
    });
    anchorBtn.appendChild(picker);

    function closeOnOutsideClick(ev) {
      if (!anchorBtn.contains(ev.target)) {
        picker.remove();
        document.removeEventListener("click", closeOnOutsideClick);
      }
    }
    setTimeout(function () { document.addEventListener("click", closeOnOutsideClick); }, 0);
  }

  function renderBoard() {
    var board = document.getElementById("board");
    board.innerHTML = "";
    var servicio = getServicio(currentServicioId);
    renderBoardHeader();

    if (!servicio) {
      var empty = document.createElement("div");
      empty.className = "empty-state";
      empty.textContent = "No hay servicios todavía. Creá uno desde el panel de la izquierda.";
      board.appendChild(empty);
      return;
    }

    servicio.planes.forEach(function (plan, index) {
      board.appendChild(renderPlanColumn(servicio, plan, index));
    });

    var addPlanBtn = document.createElement("button");
    addPlanBtn.className = "add-plan-column";
    addPlanBtn.textContent = "+ Añadir plan";
    addPlanBtn.addEventListener("click", function () { addPlan(servicio); });
    board.appendChild(addPlanBtn);
  }

  function addPlan(servicio) {
    servicio.planes.push({
      id: uid("plan"),
      nombre: "Nuevo plan",
      precio: 0,
      heredaDeInferior: servicio.planes.length > 0,
      caracteristicas: []
    });
    saveState();
    renderBoard();
  }

  function deletePlan(servicio, plan) {
    if (!confirm('¿Eliminar el plan "' + plan.nombre + '"?')) return;
    servicio.planes = servicio.planes.filter(function (p) { return p.id !== plan.id; });
    saveState();
    renderBoard();
  }

  function renderPlanColumn(servicio, plan, index) {
    var col = document.createElement("div");
    col.className = "plan-column";
    col.dataset.planId = plan.id;

    // ---- header (drag handle + nombre + eliminar) ----
    var header = document.createElement("div");
    header.className = "plan-column-header";

    var handle = document.createElement("span");
    handle.className = "plan-drag-handle";
    handle.textContent = "⠿";
    handle.draggable = true;

    var nameEl = document.createElement("div");
    nameEl.className = "plan-name";
    nameEl.contentEditable = "true";
    nameEl.textContent = plan.nombre;
    nameEl.addEventListener("input", function () { plan.nombre = nameEl.textContent; });
    nameEl.addEventListener("blur", function () { saveState(); });

    var delBtn = document.createElement("button");
    delBtn.className = "del-plan";
    delBtn.textContent = "✕";
    delBtn.title = "Eliminar plan";
    delBtn.addEventListener("click", function () { deletePlan(servicio, plan); });

    header.appendChild(handle);
    header.appendChild(nameEl);
    header.appendChild(delBtn);

    handle.addEventListener("dragstart", function (ev) {
      draggedPlanId = plan.id;
      ev.dataTransfer.effectAllowed = "move";
    });
    handle.addEventListener("dragend", function () { draggedPlanId = null; });

    // ---- precio ----
    var priceRow = document.createElement("div");
    priceRow.className = "plan-price-row";
    var currency = document.createElement("span");
    currency.className = "plan-price-currency";
    currency.textContent = "$";
    var priceInput = document.createElement("input");
    priceInput.className = "plan-price-input";
    priceInput.type = "number";
    priceInput.min = "0";
    priceInput.value = plan.precio;
    priceInput.addEventListener("input", function () {
      plan.precio = priceInput.value === "" ? 0 : Number(priceInput.value);
    });
    priceInput.addEventListener("blur", function () { saveState(); });
    var period = document.createElement("span");
    period.className = "plan-price-period";
    period.textContent = "/mes";
    priceRow.appendChild(currency);
    priceRow.appendChild(priceInput);
    priceRow.appendChild(period);

    // ---- heredar del plan inferior ----
    var inheritRow = document.createElement("div");
    inheritRow.className = "plan-inherit-row";
    if (index > 0) {
      var chk = document.createElement("input");
      chk.type = "checkbox";
      chk.id = "inherit-" + plan.id;
      chk.checked = !!plan.heredaDeInferior;
      chk.addEventListener("change", function () {
        plan.heredaDeInferior = chk.checked;
        saveState();
        renderBoard();
      });
      var lbl = document.createElement("label");
      lbl.htmlFor = chk.id;
      lbl.textContent = "Incluye lo de \"" + servicio.planes[index - 1].nombre + "\"";
      inheritRow.appendChild(chk);
      inheritRow.appendChild(lbl);
    } else {
      inheritRow.textContent = "Plan base";
    }

    // ---- lista de características (drag & drop) ----
    var list = document.createElement("ul");
    list.className = "plan-features";

    if (index > 0 && plan.heredaDeInferior) {
      var note = document.createElement("div");
      note.className = "inherit-note";
      note.textContent = "↳ heredadas de \"" + servicio.planes[index - 1].nombre + "\":";
      col.appendChild(header);
      col.appendChild(priceRow);
      col.appendChild(inheritRow);
      col.appendChild(note);

      getInheritedFeatures(servicio, index - 1).forEach(function (feat) {
        list.appendChild(renderFeatureCard(servicio, plan, feat, true));
      });
    } else {
      col.appendChild(header);
      col.appendChild(priceRow);
      col.appendChild(inheritRow);
    }

    plan.caracteristicas.forEach(function (feat) {
      list.appendChild(renderFeatureCard(servicio, plan, feat, false));
    });

    list.addEventListener("dragover", function (ev) {
      if (!draggedFeature) return;
      ev.preventDefault();
      col.classList.add("drag-over-col");
    });
    list.addEventListener("dragleave", function () { col.classList.remove("drag-over-col"); });
    list.addEventListener("drop", function (ev) {
      ev.preventDefault();
      col.classList.remove("drag-over-col");
      if (!draggedFeature) return;
      moveFeature(servicio, draggedFeature.planId, draggedFeature.featureId, plan.id, null);
    });

    col.appendChild(list);

    var addFeatureBtn = document.createElement("button");
    addFeatureBtn.className = "btn-add-feature";
    addFeatureBtn.textContent = "+ Añadir característica";
    addFeatureBtn.addEventListener("click", function () { addFeature(servicio, plan); });
    col.appendChild(addFeatureBtn);

    // drop de columna completa (reordenar planes)
    col.addEventListener("dragover", function (ev) {
      if (draggedPlanId === null) return;
      ev.preventDefault();
      col.classList.add("drag-over-col");
    });
    col.addEventListener("dragleave", function () { col.classList.remove("drag-over-col"); });
    col.addEventListener("drop", function (ev) {
      if (draggedPlanId === null) return;
      ev.preventDefault();
      col.classList.remove("drag-over-col");
      reorderPlanes(servicio, draggedPlanId, plan.id);
    });

    return col;
  }

  function getInheritedFeatures(servicio, index) {
    var plan = servicio.planes[index];
    var acc = [];
    if (index > 0 && plan.heredaDeInferior) {
      acc = acc.concat(getInheritedFeatures(servicio, index - 1));
    }
    acc = acc.concat(plan.caracteristicas);
    return acc;
  }

  function renderFeatureCard(servicio, plan, feature, inherited) {
    var card = document.createElement("li");
    card.className = "feature-card" + (inherited ? " inherited" : "");

    var dot = document.createElement("span");
    dot.className = "drag-dot";
    dot.textContent = inherited ? "↳" : "⠿";

    if (!inherited) {
      card.dataset.featureId = feature.id;
      dot.draggable = true;
      dot.addEventListener("dragstart", function (ev) {
        draggedFeature = { planId: plan.id, featureId: feature.id };
        card.classList.add("dragging");
        ev.dataTransfer.effectAllowed = "move";
      });
      dot.addEventListener("dragend", function () {
        draggedFeature = null;
        card.classList.remove("dragging");
      });
      card.addEventListener("dragover", function (ev) {
        if (!draggedFeature) return;
        ev.preventDefault();
        ev.stopPropagation();
      });
      card.addEventListener("drop", function (ev) {
        if (!draggedFeature) return;
        ev.preventDefault();
        ev.stopPropagation();
        moveFeature(servicio, draggedFeature.planId, draggedFeature.featureId, plan.id, feature.id);
      });
    }

    var text = document.createElement("div");
    text.className = "feature-text";
    text.textContent = feature.texto;
    if (!inherited) {
      text.contentEditable = "true";
      text.addEventListener("input", function () { feature.texto = text.textContent; });
      text.addEventListener("blur", function () { saveState(); });
    }

    card.appendChild(dot);
    card.appendChild(text);

    if (!inherited) {
      var del = document.createElement("button");
      del.className = "del-feature";
      del.textContent = "✕";
      del.addEventListener("click", function () {
        plan.caracteristicas = plan.caracteristicas.filter(function (f) { return f.id !== feature.id; });
        saveState();
        renderBoard();
      });
      card.appendChild(del);
    }

    return card;
  }

  function addFeature(servicio, plan) {
    plan.caracteristicas.push({ id: uid("feat"), texto: "Nueva característica" });
    saveState();
    renderBoard();
  }

  function reorderPlanes(servicio, fromId, toId) {
    if (fromId === toId) return;
    var arr = servicio.planes;
    var fromIdx = arr.findIndex(function (p) { return p.id === fromId; });
    var toIdx = arr.findIndex(function (p) { return p.id === toId; });
    if (fromIdx === -1 || toIdx === -1) return;
    var item = arr.splice(fromIdx, 1)[0];
    arr.splice(toIdx, 0, item);
    saveState();
    renderBoard();
  }

  function moveFeature(servicio, fromPlanId, featureId, toPlanId, beforeFeatureId) {
    var fromPlan = servicio.planes.find(function (p) { return p.id === fromPlanId; });
    var toPlan = servicio.planes.find(function (p) { return p.id === toPlanId; });
    if (!fromPlan || !toPlan) return;
    var idx = fromPlan.caracteristicas.findIndex(function (f) { return f.id === featureId; });
    if (idx === -1) return;
    var feature = fromPlan.caracteristicas.splice(idx, 1)[0];

    if (fromPlan.id === toPlan.id && beforeFeatureId) {
      var insertIdx = toPlan.caracteristicas.findIndex(function (f) { return f.id === beforeFeatureId; });
      toPlan.caracteristicas.splice(insertIdx === -1 ? toPlan.caracteristicas.length : insertIdx, 0, feature);
    } else if (beforeFeatureId) {
      var insertIdx2 = toPlan.caracteristicas.findIndex(function (f) { return f.id === beforeFeatureId; });
      toPlan.caracteristicas.splice(insertIdx2 === -1 ? toPlan.caracteristicas.length : insertIdx2, 0, feature);
    } else {
      toPlan.caracteristicas.push(feature);
    }
    saveState();
    renderBoard();
  }

  // ---------------------------------------------------------------------
  // Render: vista previa (lo que vería el usuario final / página de inicio)
  // ---------------------------------------------------------------------
  function renderPreview() {
    var container = document.getElementById("previewContent");
    container.innerHTML = "";

    if (!state.servicios.length) {
      var empty = document.createElement("div");
      empty.className = "empty-state";
      empty.textContent = "Todavía no configuraste ningún servicio.";
      container.appendChild(empty);
      return;
    }

    state.servicios.forEach(function (servicio) {
      var section = document.createElement("div");
      section.className = "preview-servicio";

      var headerEl = document.createElement("div");
      headerEl.className = "preview-servicio-header";
      var icon = document.createElement("span");
      icon.className = "icon";
      icon.textContent = servicio.icono || "🧩";
      var h2 = document.createElement("h2");
      h2.textContent = servicio.nombre;
      headerEl.appendChild(icon);
      headerEl.appendChild(h2);
      section.appendChild(headerEl);

      var plansWrap = document.createElement("div");
      plansWrap.className = "preview-plans";

      servicio.planes.forEach(function (plan, index) {
        var card = document.createElement("div");
        card.className = "preview-plan-card" + (index === servicio.planes.length - 1 && servicio.planes.length > 1 ? " featured" : "");

        var h3 = document.createElement("h3");
        h3.textContent = plan.nombre;
        card.appendChild(h3);

        var price = document.createElement("div");
        price.className = "preview-price";
        price.innerHTML = money(plan.precio) + " <small>/mes</small>";
        card.appendChild(price);

        if (index > 0 && plan.heredaDeInferior) {
          var includes = document.createElement("div");
          includes.className = "preview-includes";
          includes.textContent = "Incluye todo lo de \"" + servicio.planes[index - 1].nombre + "\", además:";
          card.appendChild(includes);
        }

        var ul = document.createElement("ul");
        ul.className = "preview-feature-list";

        if (index > 0 && plan.heredaDeInferior) {
          getInheritedFeatures(servicio, index - 1).forEach(function (feat) {
            var li = document.createElement("li");
            li.className = "inherited";
            li.textContent = feat.texto;
            ul.appendChild(li);
          });
        }
        plan.caracteristicas.forEach(function (feat) {
          var li = document.createElement("li");
          li.textContent = feat.texto;
          ul.appendChild(li);
        });
        if (!ul.children.length) {
          var liEmpty = document.createElement("li");
          liEmpty.textContent = "Sin características cargadas";
          liEmpty.style.opacity = "0.6";
          ul.appendChild(liEmpty);
        }
        card.appendChild(ul);

        var payBtn = document.createElement("button");
        payBtn.className = "btn-pagar";
        payBtn.textContent = "Pagar / Suscribirme";
        payBtn.addEventListener("click", function () { onPagarClick(servicio.id, plan.id); });
        card.appendChild(payBtn);

        plansWrap.appendChild(card);
      });

      section.appendChild(plansWrap);
      container.appendChild(section);
    });
  }

  // ---------------------------------------------------------------------
  // Login / Pago
  // ---------------------------------------------------------------------
  function openModal(id) { document.getElementById(id).classList.remove("hidden"); }
  function closeModal(id) { document.getElementById(id).classList.add("hidden"); }

  function openLoginModal() {
    document.getElementById("loginForm").reset();
    openModal("loginModal");
  }

  function onPagarClick(servicioId, planId) {
    pendingPayment = { servicioId: servicioId, planId: planId };
    if (!getCurrentUser()) {
      openLoginModal();
      return;
    }
    openPayModal();
  }

  function openPayModal() {
    if (!pendingPayment) return;
    var servicio = getServicio(pendingPayment.servicioId);
    if (!servicio) { pendingPayment = null; return; }
    var plan = servicio.planes.find(function (p) { return p.id === pendingPayment.planId; });
    if (!plan) { pendingPayment = null; return; }
    var user = getCurrentUser();

    var body = document.getElementById("payModalBody");
    body.innerHTML = "";

    var h3 = document.createElement("h3");
    h3.textContent = "Confirmar suscripción";
    var sub = document.createElement("p");
    sub.className = "modal-sub";
    sub.textContent = "Sesión iniciada como " + (user ? user.email : "");

    var summary = document.createElement("div");
    summary.className = "pay-summary";
    summary.innerHTML =
      '<div class="row"><span>Servicio</span><span>' + servicio.icono + " " + servicio.nombre + '</span></div>' +
      '<div class="row"><span>Plan</span><span>' + plan.nombre + '</span></div>' +
      '<div class="row total"><span>Total</span><span>' + money(plan.precio) + '/mes</span></div>';

    var actions = document.createElement("div");
    actions.className = "modal-actions";
    var cancelBtn = document.createElement("button");
    cancelBtn.className = "btn-ghost";
    cancelBtn.textContent = "Cancelar";
    cancelBtn.addEventListener("click", function () { closeModal("payModal"); pendingPayment = null; });

    var confirmBtn = document.createElement("button");
    confirmBtn.className = "btn-primary";
    confirmBtn.textContent = "Confirmar pago";
    confirmBtn.addEventListener("click", function () {
      confirmBtn.disabled = true;
      confirmBtn.textContent = "Procesando…";
      setTimeout(function () { renderPaySuccess(servicio, plan, user); }, 600);
    });

    actions.appendChild(cancelBtn);
    actions.appendChild(confirmBtn);

    body.appendChild(h3);
    body.appendChild(sub);
    body.appendChild(summary);
    body.appendChild(actions);

    openModal("payModal");
  }

  function renderPaySuccess(servicio, plan, user) {
    var body = document.getElementById("payModalBody");
    body.innerHTML = "";
    var wrap = document.createElement("div");
    wrap.className = "pay-success";
    wrap.innerHTML =
      '<div class="big-check">✅</div>' +
      "<h3>¡Pago simulado con éxito!</h3>" +
      "<p class=\"modal-sub\">" + (user ? user.email : "") + " ahora tiene el plan <strong>" + plan.nombre +
      "</strong> de <strong>" + servicio.nombre + "</strong> (" + money(plan.precio) + "/mes).</p>";
    var closeBtn = document.createElement("button");
    closeBtn.className = "btn-primary";
    closeBtn.textContent = "Cerrar";
    closeBtn.addEventListener("click", function () { closeModal("payModal"); pendingPayment = null; });
    wrap.appendChild(closeBtn);
    body.appendChild(wrap);
  }

  // ---------------------------------------------------------------------
  // Exportar / Importar configuración (archivo plano .json)
  // ---------------------------------------------------------------------
  function exportConfig() {
    var blob = new Blob([JSON.stringify(state, null, 2)], { type: "application/json" });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = "config-servicios.json";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  function importConfig(file) {
    var reader = new FileReader();
    reader.onload = function () {
      try {
        var parsed = JSON.parse(reader.result);
        if (!parsed || !Array.isArray(parsed.servicios)) throw new Error("Formato inválido");
        state = parsed;
        currentServicioId = state.servicios.length ? state.servicios[0].id : null;
        saveState();
        renderSidebar();
        renderBoard();
        renderPreview();
      } catch (e) {
        alert("No se pudo importar el archivo: " + e.message);
      }
    };
    reader.readAsText(file);
  }

  // ---------------------------------------------------------------------
  // Tabs
  // ---------------------------------------------------------------------
  function switchTab(tab) {
    document.querySelectorAll(".tab-btn").forEach(function (b) {
      b.classList.toggle("active", b.dataset.tab === tab);
    });
    document.getElementById("editorView").classList.toggle("active", tab === "editor");
    document.getElementById("previewView").classList.toggle("active", tab === "preview");
    if (tab === "preview") renderPreview();
  }

  // ---------------------------------------------------------------------
  // Wiring inicial
  // ---------------------------------------------------------------------
  function init() {
    document.getElementById("tabs").addEventListener("click", function (ev) {
      var btn = ev.target.closest(".tab-btn");
      if (btn) switchTab(btn.dataset.tab);
    });

    document.getElementById("btnAddServicio").addEventListener("click", addServicio);
    document.getElementById("btnExport").addEventListener("click", exportConfig);
    document.getElementById("importFile").addEventListener("change", function (ev) {
      if (ev.target.files && ev.target.files[0]) importConfig(ev.target.files[0]);
      ev.target.value = "";
    });

    document.querySelectorAll("[data-close]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        closeModal(btn.dataset.close);
        if (btn.dataset.close === "payModal") pendingPayment = null;
      });
    });
    document.querySelectorAll(".modal-overlay").forEach(function (overlay) {
      overlay.addEventListener("click", function (ev) {
        if (ev.target === overlay) {
          overlay.classList.add("hidden");
          if (overlay.id === "payModal") pendingPayment = null;
        }
      });
    });

    document.getElementById("loginForm").addEventListener("submit", function (ev) {
      ev.preventDefault();
      var email = document.getElementById("loginEmail").value.trim();
      if (!email) return;
      setCurrentUser({ email: email });
      renderAuthArea();
      closeModal("loginModal");
      if (pendingPayment) openPayModal();
    });

    document.getElementById("btnDemoLogin").addEventListener("click", function () {
      document.getElementById("loginEmail").value = "demo@correo.com";
      document.getElementById("loginPassword").value = "demo1234";
      setCurrentUser({ email: "demo@correo.com" });
      renderAuthArea();
      closeModal("loginModal");
      if (pendingPayment) openPayModal();
    });

    renderAuthArea();
    renderSidebar();
    renderBoard();
  }

  document.addEventListener("DOMContentLoaded", init);
})();
