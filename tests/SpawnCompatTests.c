#include <assert.h>
#include <string.h>
#include <spawn.h>
#include <dlfcn.h>

// Simulate the SDK availability annotations that broke the original tvOS build.
extern int posix_spawnattr_init(posix_spawnattr_t *) __attribute__((unavailable("tvOS SDK test")));
extern int posix_spawnattr_destroy(posix_spawnattr_t *) __attribute__((unavailable("tvOS SDK test")));
extern int posix_spawn_file_actions_init(posix_spawn_file_actions_t *) __attribute__((unavailable("tvOS SDK test")));
extern int posix_spawn_file_actions_destroy(posix_spawn_file_actions_t *) __attribute__((unavailable("tvOS SDK test")));
extern int posix_spawn(pid_t *, const char *, const posix_spawn_file_actions_t *, const posix_spawnattr_t *, char *const [], char *const []) __attribute__((unavailable("tvOS SDK test")));

static const char *missingSymbol = NULL;
static int dummy(void) { return 0; }
static void *fakeDlsym(void *handle, const char *symbol) {
    (void)handle;
    if (missingSymbol && strcmp(missingSymbol, symbol) == 0) return NULL;
    return (void *)dummy;
}
#define dlsym fakeDlsym
#include "../TrollAppsTV/TrollAppsTV/Objective C/SpawnCompat.h"
#undef dlsym

int main(void) {
    TSSpawnAPI api;
    assert(TSLoadSpawnAPI(&api) == 0);
    const char *symbols[] = {
        "posix_spawnattr_init", "posix_spawnattr_destroy", "posix_spawn_file_actions_init",
        "posix_spawn_file_actions_destroy", "posix_spawn", "posix_spawnattr_set_persona_np",
        "posix_spawnattr_set_persona_uid_np", "posix_spawnattr_set_persona_gid_np"
    };
    for (unsigned i = 0; i < sizeof(symbols) / sizeof(symbols[0]); i++) {
        missingSymbol = symbols[i];
        assert(TSLoadSpawnAPI(&api) == ENOSYS);
    }
    return 0;
}
