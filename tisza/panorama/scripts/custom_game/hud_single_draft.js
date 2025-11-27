(function() {
    GameEvents.Subscribe("single_draft_set_heroes", function(data) {
        $.Msg("[TISZA] Heroes received:", data.heroes)

        // Gyári Single Draft UI-nak átadjuk
        if (GameUI.CustomUIConfig && GameUI.CustomUIConfig().hero_selection) {
            GameUI.CustomUIConfig().hero_selection.SetAvailableHeroes(data.heroes);
        }
    });
})();
