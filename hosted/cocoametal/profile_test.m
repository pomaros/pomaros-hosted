#import <Foundation/Foundation.h>
#include "profile_migration.h"
#include <assert.h>
#include <stdio.h>

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *current = [@{@"sharing.clipboard": @NO} mutableCopy];
        NSDictionary *legacy = @{@"sharing.clipboard": @YES, @"sound.volume": @42,
                                  @"unrelated": @"keep out", @"cocoametal.fullscreen": @YES};
        NSSet *keys = [NSSet setWithArray:@[@"sharing.clipboard", @"sound.volume", @"cocoametal.fullscreen"]];
        cm_profile_merge_defaults(current, legacy, keys);
        assert([current[@"sharing.clipboard"] isEqual:@NO]);
        assert([current[@"sound.volume"] isEqual:@42]);
        assert(!current[@"unrelated"]);
        assert(!current[@"cocoametal.fullscreen"]);
        cm_profile_merge_defaults(current, @{@"sound.volume": @90}, keys);
        assert([current[@"sound.volume"] isEqual:@42]);
        assert([legacy[@"sharing.clipboard"] isEqual:@YES]);
        puts("[PROFILE] PASS absent settings imported, explicit false retained, source unchanged");
    }
    return 0;
}
