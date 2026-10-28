// Based on TrollAppsTV's TSUtil.m by Hornbeck. Distributed under GPL-3.0.
#import <Foundation/Foundation.h>
#import <sys/wait.h>
#import <errno.h>
#import <unistd.h>
#import <stdlib.h>
#import <string.h>
#import "TrollAppsTV-Bridging-Header.h"
#import "CoreServices.h"
#import "SpawnCompat.h"

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1

bool openApplicationWithBundleID(NSString *appId) {
    return [[LSApplicationWorkspace defaultWorkspace] openApplicationWithBundleID:appId];
}

int spawnRoot(NSString *path, NSArray *args) {
    TSSpawnAPI api;
    int result = TSLoadSpawnAPI(&api);
    if (result != 0) {
        NSLog(@"Root helper launch APIs are unavailable (code %d)", result);
        return result;
    }
    NSMutableArray *arguments = args.mutableCopy ?: [NSMutableArray new];
    [arguments insertObject:path.lastPathComponent atIndex:0];
    NSUInteger count = arguments.count;
    char **argv = calloc(count + 1, sizeof(char *));
    if (!argv) return ENOMEM;
    for (NSUInteger i = 0; i < count; i++) {
        argv[i] = strdup([arguments[i] UTF8String]);
        if (!argv[i]) {
            for (NSUInteger j = 0; j < i; j++) free(argv[j]);
            free(argv);
            return ENOMEM;
        }
    }
    posix_spawnattr_t attr;
    posix_spawn_file_actions_t actions;
    BOOL attrReady = NO;
    BOOL actionsReady = NO;
    pid_t child = 0;
    result = api.attrInit(&attr);
    if (result == 0) {
        attrReady = YES;
        result = api.setPersona(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
    }
    if (result == 0) result = api.setUID(&attr, 0);
    if (result == 0) result = api.setGID(&attr, 0);
    if (result == 0) {
        result = api.actionsInit(&actions);
        actionsReady = (result == 0);
    }
    if (result == 0) result = api.spawn(&child, path.fileSystemRepresentation, &actions, &attr, argv, NULL);
    if (actionsReady) api.actionsDestroy(&actions);
    if (attrReady) api.attrDestroy(&attr);
    for (NSUInteger i = 0; i < count; i++) free(argv[i]);
    free(argv);
    if (result != 0) {
        NSLog(@"Root helper launch failed: %d (%s)", result, strerror(result));
        return result;
    }
    int status = 0;
    while (waitpid(child, &status, 0) == -1) {
        if (errno == EINTR) continue;
        perror("waitpid");
        return -222;
    }
    if (WIFSIGNALED(status)) return 128 + WTERMSIG(status);
    if (!WIFEXITED(status)) return -222;
    return WEXITSTATUS(status);
}
