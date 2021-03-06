#import "BSGConfigurationBuilder.h"

#import "BSG_KSLogger.h"
#import "BugsnagConfiguration.h"
#import "BugsnagEndpointConfiguration.h"
#import "BugsnagKeys.h"

static BOOL BSGValueIsBoolean(id object) {
    return object != nil && [object isKindOfClass:[NSNumber class]]
            && CFGetTypeID((__bridge CFTypeRef)object) == CFBooleanGetTypeID();
}

@implementation BSGConfigurationBuilder

+ (BugsnagConfiguration *)configurationFromOptions:(NSDictionary *)options {
    NSString *apiKey = options[BSGKeyApiKey];
    if (apiKey != nil && ![apiKey isKindOfClass:[NSString class]]) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Bugsnag apiKey must be a string" userInfo:nil];
    }

    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:apiKey];

    NSArray<NSString *> *validKeys = @[
        BSGKeyApiKey,
        BSGKeyAppType,
        BSGKeyAppVersion,
        BSGKeyAutoDetectErrors,
        BSGKeyAutoTrackSessions,
        BSGKeyBundleVersion,
        BSGKeyEnabledReleaseStages,
        BSGKeyEndpoints,
        BSGKeyMaxBreadcrumbs,
        BSGKeyPersistUser,
        BSGKeyRedactedKeys,
        BSGKeyReleaseStage,
        BSGKeySendThreads,
    ];
    
    NSMutableSet *unknownKeys = [NSMutableSet setWithArray:options.allKeys];
    [unknownKeys minusSet:[NSSet setWithArray:validKeys]];
    if (unknownKeys.count > 0) {
        BSG_KSLOG_WARN(@"Unknown dictionary keys passed in configuration options: %@", unknownKeys);
    }
    
    [self loadString:config options:options key:BSGKeyAppType];
    [self loadString:config options:options key:BSGKeyAppVersion];
    [self loadBoolean:config options:options key:BSGKeyAutoDetectErrors];
    [self loadBoolean:config options:options key:BSGKeyAutoTrackSessions];
    [self loadString:config options:options key:BSGKeyBundleVersion];
    [self loadBoolean:config options:options key:BSGKeyPersistUser];
    [self loadString:config options:options key:BSGKeyReleaseStage];

    [self loadStringArray:config options:options key:BSGKeyEnabledReleaseStages];
    [self loadStringArray:config options:options key:BSGKeyRedactedKeys];
    [self loadEndpoints:config options:options];

    [self loadMaxBreadcrumbs:config options:options];
    [self loadSendThreads:config options:options];
    return config;
}

+ (void)loadBoolean:(BugsnagConfiguration *)config options:(NSDictionary *)options key:(NSString *)key {
    if (BSGValueIsBoolean(options[key])) {
        [config setValue:options[key] forKey:key];
    }
}

+ (void)loadString:(BugsnagConfiguration *)config options:(NSDictionary *)options key:(NSString *)key {
    if (options[key] && [options[key] isKindOfClass:[NSString class]]) {
        [config setValue:options[key] forKey:key];
    }
}

+ (void)loadStringArray:(BugsnagConfiguration *)config options:(NSDictionary *)options key:(NSString *)key {
    if (options[key] && [options[key] isKindOfClass:[NSArray class]]) {
        NSArray *val = options[key];

        for (NSString *obj in val) {
            if (![obj isKindOfClass:[NSString class]]) {
                return;
            }
        }
        [config setValue:val forKey:key];
    }
}

+ (void)loadEndpoints:(BugsnagConfiguration *)config options:(NSDictionary *)options {
    if (options[BSGKeyEndpoints] && [options[BSGKeyEndpoints] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *endpoints = options[BSGKeyEndpoints];

        if ([endpoints[BSGKeyNotifyEndpoint] isKindOfClass:[NSString class]]) {
            config.endpoints.notify = endpoints[BSGKeyNotifyEndpoint];
        }
        if ([endpoints[BSGKeySessionsEndpoint] isKindOfClass:[NSString class]]) {
            config.endpoints.sessions = endpoints[BSGKeySessionsEndpoint];
        }
    }
}

+ (void)loadMaxBreadcrumbs:(BugsnagConfiguration *)config options:(NSDictionary *)options {
    if (options[BSGKeyMaxBreadcrumbs] && [options[BSGKeyMaxBreadcrumbs] isKindOfClass:[NSNumber class]]) {
        NSNumber *num = options[BSGKeyMaxBreadcrumbs];
        config.maxBreadcrumbs = [num unsignedIntValue];
    }
}

+ (void)loadSendThreads:(BugsnagConfiguration *)config options:(NSDictionary *)options {
    if (options[BSGKeySendThreads] && [options[BSGKeySendThreads] isKindOfClass:[NSString class]]) {
        NSString *sendThreads = [options[BSGKeySendThreads] lowercaseString];

        if ([@"unhandledonly" isEqualToString:sendThreads]) {
            config.sendThreads = BSGThreadSendPolicyUnhandledOnly;
        } else if ([@"always" isEqualToString:sendThreads]) {
            config.sendThreads = BSGThreadSendPolicyAlways;
        } else if ([@"never" isEqualToString:sendThreads]) {
            config.sendThreads = BSGThreadSendPolicyNever;
        }
    }
}

@end
