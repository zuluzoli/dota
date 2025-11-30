(() => {
  $.Msg("[HeroPool] Script loaded");
  const container = $("#HeroPoolContainer");

  function hideDefaultHeroSelection() {
    $.Msg("[HeroPool] Attempting to hide default hero selection");
    // Attempt to hide common hero selection containers
    const ids = [
      "HeroSelection",
      "PreGame",
      "HeroGrid",
      "HeroPickGrid",
      "HeroSelectionContainer",
      "SharedHeroSelectorAndLoadout",
      "HeroPickScreen",
      "TeamSelectContainer",
      "StrategyScreen",
      "PreMinimapContainer",
      "HUDElements",
      "PreGameStrategyPhase",
    ];
    ids.forEach((id) => {
      const panel = $("#" + id);
      if (panel) {
        panel.style.visibility = "collapse";
        panel.style.opacity = "0";
        panel.style.zIndex = "-1";
        $.Msg("[HeroPool] Hidden panel: " + id);
      }
    });

    // Try to find and hide the root hero selection
    const dotaHud = $.GetContextPanel().GetParent();
    if (dotaHud) {
      const hudElements =
        dotaHud.FindChildrenWithClassTraverse("HeroSelection");
      hudElements.forEach((el) => {
        el.style.visibility = "collapse";
        el.style.opacity = "0";
      });
    }

    // Hide all siblings of root to be safe
    const root = $("#HeroPoolRoot");
    if (root && root.GetParent()) {
      const parent = root.GetParent();
      const children = parent.Children();
      children.forEach((p) => {
        if (p !== root) {
          p.style.visibility = "collapse";
          p.style.opacity = "0";
        }
      });
    }
  }

  function renderPool(heroes) {
    $.Msg(
      "[HeroPool] Rendering pool with " +
        (heroes ? heroes.length : 0) +
        " heroes"
    );
    container.RemoveAndDeleteChildren();
    if (!heroes || heroes.length === 0) {
      $.Msg("[HeroPool] No heroes to render");
      const label = $.CreatePanel("Label", container, "NoHeroes");
      label.text = "No allowed heroes";
      label.style.color = "#ff0000";
      label.style.fontSize = "24px";
      return;
    }
    $.Msg("[HeroPool] Heroes: " + JSON.stringify(heroes));
    heroes.forEach((name) => {
      const btn = $.CreatePanel("Button", container, "btn_" + name);
      btn.AddClass("HeroButton");
      btn.style.width = "128px";
      btn.style.height = "128px";
      btn.style.margin = "8px";
      btn.style.backgroundColor = "#222";
      btn.style.border = "2px solid #666";

      const img = $.CreatePanel("Image", btn, "img_" + name);
      img.style.width = "64px";
      img.style.height = "64px";
      img.style.horizontalAlign = "center";
      img.SetImage("file://{images}/heroes/icons/" + name + ".png");

      const lbl = $.CreatePanel("Label", btn, "lbl_" + name);
      lbl.text = name.replace("npc_dota_hero_", "");
      lbl.style.color = "#fff";
      lbl.style.fontSize = "14px";
      lbl.style.horizontalAlign = "center";

      btn.SetPanelEvent("onactivate", () => {
        $.Msg("[HeroPool] Clicked hero: " + name);
        const pid = Players.GetLocalPlayer();
        GameEvents.SendCustomGameEventToServer("hero_pool_select", {
          PlayerID: pid,
          hero: name,
        });
      });
    });
  }

  function updateFromNetTable() {
    const pid = Players.GetLocalPlayer();
    $.Msg("[HeroPool] Local player ID: " + pid);
    const data = CustomNetTables.GetTableValue("hero_pools", pid.toString());
    $.Msg("[HeroPool] Net table data: " + JSON.stringify(data));
    renderPool(data && data.heroes ? data.heroes : []);
  }

  // Initialize
  hideDefaultHeroSelection();
  updateFromNetTable();

  CustomNetTables.SubscribeNetTableListener(
    "hero_pools",
    (table, key, value) => {
      const pid = Players.GetLocalPlayer();
      if (table === "hero_pools" && key === pid.toString()) {
        renderPool(value && value.heroes ? value.heroes : []);
      }
    }
  );
})();
