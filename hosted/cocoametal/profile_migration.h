#import <Foundation/Foundation.h>

/* Merge only product settings, preserving every explicit destination value. */
static inline void cm_profile_merge_defaults(NSMutableDictionary *destination,
                                              NSDictionary *legacy,
                                              NSSet<NSString *> *keys)
{
    for (NSString *key in keys)
        if (![key isEqual:@"cocoametal.fullscreen"] && !destination[key] && legacy[key])
            destination[key] = legacy[key];
}
