// Runtime lookup for process-launch APIs hidden by newer tvOS SDK headers.
// This code is for a jailbroken/TrollStore environment, not App Store distribution.
#ifndef TS_SPAWN_COMPAT_H
#define TS_SPAWN_COMPAT_H
#include <spawn.h>
#include <dlfcn.h>
#include <errno.h>
#include <sys/types.h>

typedef int (*TSAttrOperation)(posix_spawnattr_t *);
typedef int (*TSActionsOperation)(posix_spawn_file_actions_t *);
typedef int (*TSSpawnOperation)(pid_t *, const char *, const posix_spawn_file_actions_t *,
                               const posix_spawnattr_t *, char *const [], char *const []);
typedef int (*TSPersonaOperation)(const posix_spawnattr_t *, uid_t, unsigned int);
typedef int (*TSUserOperation)(const posix_spawnattr_t *, uid_t);
typedef int (*TSGroupOperation)(const posix_spawnattr_t *, gid_t);

typedef struct {
    TSAttrOperation attrInit;
    TSAttrOperation attrDestroy;
    TSActionsOperation actionsInit;
    TSActionsOperation actionsDestroy;
    TSSpawnOperation spawn;
    TSPersonaOperation setPersona;
    TSUserOperation setUID;
    TSGroupOperation setGID;
} TSSpawnAPI;

static inline int TSLoadSpawnAPI(TSSpawnAPI *api) {
    api->attrInit = (TSAttrOperation)dlsym(RTLD_DEFAULT, "posix_spawnattr_init");
    api->attrDestroy = (TSAttrOperation)dlsym(RTLD_DEFAULT, "posix_spawnattr_destroy");
    api->actionsInit = (TSActionsOperation)dlsym(RTLD_DEFAULT, "posix_spawn_file_actions_init");
    api->actionsDestroy = (TSActionsOperation)dlsym(RTLD_DEFAULT, "posix_spawn_file_actions_destroy");
    api->spawn = (TSSpawnOperation)dlsym(RTLD_DEFAULT, "posix_spawn");
    api->setPersona = (TSPersonaOperation)dlsym(RTLD_DEFAULT, "posix_spawnattr_set_persona_np");
    api->setUID = (TSUserOperation)dlsym(RTLD_DEFAULT, "posix_spawnattr_set_persona_uid_np");
    api->setGID = (TSGroupOperation)dlsym(RTLD_DEFAULT, "posix_spawnattr_set_persona_gid_np");
    if (!api->attrInit || !api->attrDestroy || !api->actionsInit || !api->actionsDestroy ||
        !api->spawn || !api->setPersona || !api->setUID || !api->setGID) return ENOSYS;
    return 0;
}
#endif
