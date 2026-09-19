// Portable integration test of the actual consumer. The iOS transport and
// rendering entrypoints are removed by section GC; only touch submission is a
// stub, so this never sends input to a device.
#include "../lara/kexploit/wzesp.mm"
#include <cassert>

static int taps = 0;
static bool acceptTap = true;
extern "C" bool wzax_touch_tap(double x, double y, bool fixed) {
    assert(x == 100 && y == 200 && fixed);
    ++taps;
    return acceptTap;
}

int main() {
    KoiEntity target{};
    target.axPositionValid = 1;
    KoiEntity observers[2]{};
    observers[0].category = KoiEntityCategorySoldier;
    observers[0].axPositionValid = 1;
    observers[0].axWorldX = 12;
    observers[0].exposureState = 1;
    assert(AXMinimapExposed(target, observers, 2)); // Inclusive 12m edge.
    observers[0].axWorldX = 12.01f;
    assert(!AXMinimapExposed(target, observers, 2));
    observers[0].axWorldX = 1;
    observers[0].exposureState = 0;
    assert(!AXMinimapExposed(target, observers, 2)); // Dead soldier cannot see.
    observers[1].category = KoiEntityCategoryHero;
    observers[1].axPositionValid = 1;
    observers[1].axWorldX = 1;
    observers[1].axDead = 1; // AX's friendly-hero scan does not test this byte.
    observers[1].visibility = KoiVisibilityFogged;
    assert(AXMinimapExposed(target, observers, 2));
    observers[1].enemy = 1;
    assert(!AXMinimapExposed(target, observers, 2));

    wzesp_config_t config{};
    config.flags = WZESP_AUTO_KILL;
    config.clickX = 100;
    config.clickY = 200;
    config.clickCoordinatesValid = 1;
    config.clickSpaceFixed = 1;
    KoiRuntimeDiagnostics state{};
    state.autoKillSampleValid = 1;
    KoiEntity enemies[2]{};
    for (auto &enemy : enemies) {
        enemy.category = KoiEntityCategoryHero;
        enemy.enemy = 1;
        enemy.axPositionValid = enemy.axHealthValid = 1;
        enemy.axWorldX = enemy.axWorldZ = 1;
        enemy.axHealth = 100;
        enemy.axHealthTotal = 1000;
    }
    assert(TryAXAutoKill(config, state, enemies, 2) == 4 && taps == 1);
    assert(TryAXAutoKill(config, state, enemies, 2) == 3 && taps == 1);
    g_autoKillNextAllowed.store(0);
    state.autoKillSampleValid = 0;
    assert(TryAXAutoKill(config, state, enemies, 2) == 1 && taps == 1);
    state.autoKillSampleValid = 1;
    state.autoKillGateB = 1;
    assert(TryAXAutoKill(config, state, enemies, 2) == 1 && taps == 1);
    state.autoKillGateB = 0;
    config.clickCoordinatesValid = 0;
    assert(TryAXAutoKill(config, state, enemies, 2) == 2 && taps == 1);
    config.clickCoordinatesValid = 1;
    acceptTap = false;
    assert(TryAXAutoKill(config, state, enemies, 2) == 5 && taps == 2);
    assert(g_autoKillNextAllowed.load() == 0);
    acceptTap = true;
    assert(TryAXAutoKill(config, state, enemies, 2) == 4 && taps == 3);
    config.flags = 0;
    assert(TryAXAutoKill(config, state, enemies, 2) == 0 && taps == 3);
}
