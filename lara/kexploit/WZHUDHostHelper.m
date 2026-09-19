#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

#include <dlfcn.h>
#include <errno.h>
#include <limits.h>
#include <math.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static NSString *const WZRegisterSelectorName =
    @"registerWindowWithContextID:atLevel:";
static NSString *const WZUnregisterSelectorName =
    @"unregisterWindowWithContextID:";

static NSLock *WZStateLock;
static NSMutableArray *WZHostingControllers;
static uint32_t WZHostedContextIDs[3];
static CFRunLoopRef WZMainRunLoop;
static pid_t WZParentProcessID;
static atomic_bool WZShutdownStarted = false;

static void WZPrintUsage(const char *program) {
    fprintf(stderr,
            "usage: %s --ready <path> "
            "--context <id0> <window-level0> "
            "--context <id1> <window-level1> "
            "--context <id2> <window-level2>\n"
            "       %s --stop <pid>\n",
            program ?: "WZHUDHostHelper",
            program ?: "WZHUDHostHelper");
}

static BOOL WZParseProcessID(const char *value, pid_t *result) {
    if (!value || !value[0] || !result || value[0] == '-') return NO;

    errno = 0;
    char *end = NULL;
    long long parsed = strtoll(value, &end, 10);
    if (errno != 0 || end == value || *end != '\0' ||
        parsed <= 1 || parsed > INT_MAX) {
        return NO;
    }
    *result = (pid_t)parsed;
    return YES;
}

static BOOL WZParseContextID(const char *value, uint32_t *result) {
    if (!value || !value[0] || !result || value[0] == '-') return NO;

    errno = 0;
    char *end = NULL;
    unsigned long long parsed = strtoull(value, &end, 0);
    if (errno != 0 || end == value || *end != '\0' ||
        parsed == 0 || parsed > UINT32_MAX) {
        return NO;
    }
    *result = (uint32_t)parsed;
    return YES;
}

static BOOL WZParseWindowLevel(const char *value, double *result) {
    if (!value || !value[0] || !result) return NO;

    errno = 0;
    char *end = NULL;
    double parsed = strtod(value, &end);
    if (errno != 0 || end == value || *end != '\0' || !isfinite(parsed)) {
        return NO;
    }
    *result = parsed;
    return YES;
}

static BOOL WZInvokeRegister(id controller, uint32_t contextID,
                             double windowLevel, NSError **error) {
    SEL selector = NSSelectorFromString(WZRegisterSelectorName);
    if (!controller || contextID == 0 ||
        ![controller respondsToSelector:selector]) {
        if (error) {
            *error = [NSError errorWithDomain:@"WZHUDHostHelper"
                                         code:10
                                     userInfo:@{
                NSLocalizedDescriptionKey:
                    @"hosting controller does not support registration"
            }];
        }
        return NO;
    }

    NSMethodSignature *signature =
        [NSMethodSignature signatureWithObjCTypes:"v@:Id"];
    if (!signature || signature.numberOfArguments != 4 ||
        signature.methodReturnLength != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"WZHUDHostHelper"
                                         code:11
                                     userInfo:@{
                NSLocalizedDescriptionKey:
                    @"unable to construct v@:Id registration signature"
            }];
        }
        return NO;
    }

    @try {
        NSInvocation *invocation =
            [NSInvocation invocationWithMethodSignature:signature];
        invocation.target = controller;
        invocation.selector = selector;
        [invocation setArgument:&contextID atIndex:2];
        [invocation setArgument:&windowLevel atIndex:3];
        [invocation invoke];
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"WZHUDHostHelper"
                                         code:12
                                     userInfo:@{
                NSLocalizedDescriptionKey:
                    exception.reason ?: @"registration invocation failed"
            }];
        }
        return NO;
    }
}

static void WZInvokeUnregister(id controller, uint32_t contextID) {
    SEL selector = NSSelectorFromString(WZUnregisterSelectorName);
    if (!controller || contextID == 0 ||
        ![controller respondsToSelector:selector]) {
        return;
    }

    NSMethodSignature *signature =
        [NSMethodSignature signatureWithObjCTypes:"v@:I"];
    if (!signature || signature.numberOfArguments != 3 ||
        signature.methodReturnLength != 0) {
        return;
    }

    @try {
        NSInvocation *invocation =
            [NSInvocation invocationWithMethodSignature:signature];
        invocation.target = controller;
        invocation.selector = selector;
        [invocation setArgument:&contextID atIndex:2];
        [invocation invoke];
    } @catch (__unused NSException *exception) {
        // Shutdown is best-effort; the process exit also drops controller state.
    }
}

static void WZUnregisterAll(void) {
    [WZStateLock lock];
    for (NSInteger index = (NSInteger)WZHostingControllers.count - 1;
         index >= 0; --index) {
        id controller = WZHostingControllers[(NSUInteger)index];
        WZInvokeUnregister(controller, WZHostedContextIDs[index]);
        WZHostedContextIDs[index] = 0;
    }
    [WZHostingControllers removeAllObjects];
    [WZStateLock unlock];
}

static void WZRequestShutdown(void) {
    if (atomic_exchange_explicit(&WZShutdownStarted, true,
                                 memory_order_acq_rel)) {
        return;
    }
    WZUnregisterAll();
    if (WZMainRunLoop) CFRunLoopStop(WZMainRunLoop);
}

static dispatch_source_t WZCreateSignalSource(int signalNumber) {
    if (signal(signalNumber, SIG_IGN) == SIG_ERR) return NULL;
    dispatch_source_t source = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_SIGNAL, (uintptr_t)signalNumber, 0,
        dispatch_get_main_queue());
    if (!source) return NULL;

    dispatch_source_set_event_handler(source, ^{
        @autoreleasepool {
            WZRequestShutdown();
        }
    });
    dispatch_resume(source);
    return source;
}

static void WZKeepAlivePerform(void *info) {
    (void)info;
}

static BOOL WZWriteReadyFile(NSString *path,
                             const uint32_t contextIDs[3],
                             const double levels[3], NSError **error) {
    NSDictionary *payload = @{
        @"pid": @(getpid()),
        @"contexts": @[
            @{ @"contextID": @(contextIDs[0]), @"windowLevel": @(levels[0]) },
            @{ @"contextID": @(contextIDs[1]), @"windowLevel": @(levels[1]) },
            @{ @"contextID": @(contextIDs[2]), @"windowLevel": @(levels[2]) },
        ],
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload
                                                   options:0
                                                     error:error];
    return data && [data writeToFile:path
                             options:NSDataWritingAtomic
                               error:error];
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc == 3 && strcmp(argv[1], "--stop") == 0) {
            pid_t processID = 0;
            if (!WZParseProcessID(argv[2], &processID)) {
                WZPrintUsage(argv[0]);
                return 64;
            }
            if (kill(processID, SIGTERM) != 0) {
                fprintf(stderr, "cannot stop pid %d: %s\n",
                        (int)processID, strerror(errno));
                return 71;
            }
            return 0;
        }

        if (argc != 12 || strcmp(argv[1], "--ready") != 0 ||
            strcmp(argv[3], "--context") != 0 ||
            strcmp(argv[6], "--context") != 0 ||
            strcmp(argv[9], "--context") != 0) {
            WZPrintUsage(argv[0]);
            return 64;
        }

        NSString *readyPath = [NSString stringWithUTF8String:argv[2]];
        if (readyPath.length == 0) {
            fprintf(stderr, "invalid ready-file path\n");
            return 64;
        }
        readyPath = readyPath.stringByStandardizingPath;

        uint32_t contextIDs[3] = {0, 0, 0};
        double levels[3] = {0.0, 0.0, 0.0};
        for (NSUInteger index = 0; index < 3; ++index) {
            NSUInteger base = 4 + index * 3;
            if (!WZParseContextID(argv[base], &contextIDs[index]) ||
                !WZParseWindowLevel(argv[base + 1], &levels[index])) {
                fprintf(stderr, "invalid context/window-level group %lu\n",
                        (unsigned long)index);
                return 64;
            }
        }
        if (contextIDs[0] == contextIDs[1] ||
            contextIDs[0] == contextIDs[2] ||
            contextIDs[1] == contextIDs[2]) {
            fprintf(stderr, "context IDs must be distinct and non-zero\n");
            return 64;
        }

        NSFileManager *fileManager = NSFileManager.defaultManager;
        if ([fileManager fileExistsAtPath:readyPath]) {
            NSError *removeError = nil;
            if (![fileManager removeItemAtPath:readyPath error:&removeError]) {
                fprintf(stderr, "cannot remove stale ready file: %s\n",
                        removeError.localizedDescription.UTF8String);
                return 73;
            }
        }

        const char *frameworkPath =
            "/System/Library/PrivateFrameworks/"
            "SpringBoardServices.framework/SpringBoardServices";
        void *springBoardServices =
            dlopen(frameworkPath, RTLD_NOW | RTLD_LOCAL);
        if (!springBoardServices) {
            fprintf(stderr, "cannot load SpringBoardServices: %s\n",
                    dlerror() ?: "unknown dlopen error");
            return 69;
        }

        Class hostingClass =
            NSClassFromString(@"SBSAccessibilityWindowHostingController");
        if (!hostingClass) {
            fprintf(stderr,
                    "SBSAccessibilityWindowHostingController unavailable\n");
            dlclose(springBoardServices);
            return 69;
        }

        WZStateLock = [[NSLock alloc] init];
        WZHostingControllers = [[NSMutableArray alloc] initWithCapacity:3];
        WZParentProcessID = getppid();

        for (NSUInteger index = 0; index < 3; ++index) {
            id controller = [[hostingClass alloc] init];
            NSError *registerError = nil;
            if (!controller ||
                !WZInvokeRegister(controller, contextIDs[index], levels[index],
                                  &registerError)) {
                fprintf(stderr, "registration failed for group %lu: %s\n",
                        (unsigned long)index,
                        registerError.localizedDescription.UTF8String ?:
                            "unable to create hosting controller");
                WZUnregisterAll();
                dlclose(springBoardServices);
                return 70;
            }
            [WZHostingControllers addObject:controller];
            WZHostedContextIDs[index] = contextIDs[index];
        }

        NSError *readyError = nil;
        if (!WZWriteReadyFile(readyPath, contextIDs, levels, &readyError)) {
            fprintf(stderr, "cannot publish ready file: %s\n",
                    readyError.localizedDescription.UTF8String);
            WZUnregisterAll();
            dlclose(springBoardServices);
            return 73;
        }

        WZMainRunLoop = CFRunLoopGetCurrent();
        CFRetain(WZMainRunLoop);
        CFRunLoopSourceContext sourceContext = {0};
        sourceContext.perform = WZKeepAlivePerform;
        CFRunLoopSourceRef keepAliveSource =
            CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &sourceContext);
        if (!keepAliveSource) {
            fprintf(stderr, "cannot create keep-alive run-loop source\n");
            WZUnregisterAll();
            [[NSFileManager defaultManager] removeItemAtPath:readyPath
                                                       error:nil];
            CFRelease(WZMainRunLoop);
            WZMainRunLoop = NULL;
            dlclose(springBoardServices);
            return 70;
        }
        CFRunLoopAddSource(WZMainRunLoop, keepAliveSource,
                           kCFRunLoopDefaultMode);

        dispatch_source_t termSource = WZCreateSignalSource(SIGTERM);
        dispatch_source_t interruptSource = WZCreateSignalSource(SIGINT);
        dispatch_source_t parentSource = dispatch_source_create(
            DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        if (parentSource) {
            dispatch_source_set_timer(
                parentSource, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
                NSEC_PER_SEC, NSEC_PER_MSEC * 100);
            dispatch_source_set_event_handler(parentSource, ^{
                if (getppid() != WZParentProcessID ||
                    kill(WZParentProcessID, 0) != 0) {
                    WZRequestShutdown();
                }
            });
            dispatch_resume(parentSource);
        }
        if (!termSource || !interruptSource || !parentSource) {
            fprintf(stderr, "cannot install shutdown signal sources\n");
            WZRequestShutdown();
        } else {
            CFRunLoopRun();
        }

        if (termSource) dispatch_source_cancel(termSource);
        if (interruptSource) dispatch_source_cancel(interruptSource);
        if (parentSource) dispatch_source_cancel(parentSource);
        WZUnregisterAll();
        [[NSFileManager defaultManager] removeItemAtPath:readyPath error:nil];

        CFRunLoopRemoveSource(WZMainRunLoop, keepAliveSource,
                              kCFRunLoopDefaultMode);
        CFRelease(keepAliveSource);
        CFRelease(WZMainRunLoop);
        WZMainRunLoop = NULL;
        dlclose(springBoardServices);
        return 0;
    }
}
