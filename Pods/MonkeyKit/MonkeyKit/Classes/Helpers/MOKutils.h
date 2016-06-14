
#import <Foundation/Foundation.h>

#define BUILD_FOR_DISTRIBUTION
#define USE_JIGL_COM_API

#define COLOR_GRAY								[UIColor colorWithRed:0.451 green:0.451 blue:0.451 alpha:1.0]
#define COLOR_NEWGRAY							[UIColor colorWithRed:110.0/255 green:110.0/255 blue:110.0/255 alpha:1]
#define COLOR_GREEN								[UIColor colorWithRed:252.0/255 green:252.0/255 blue:247.0/255 alpha:1]
#define COLOR_DARK_BLUE							[UIColor colorWithRed:0.0 green:0.25 blue:0.44 alpha:1.0]
#define MY_USER_ID								[UsersManager instance].me.userId
#define MESSAGE_VIEW_DX							16.0

typedef long long int BLLong;
typedef int MOKUserId;
typedef int MOKGroupId;
typedef int MOKUpdateStamp;
typedef BLLong MOKInviteId;
NSInteger sortAZF(id arg1, id arg2, void *arg3);
NSInteger timestampSort(id arg1, id arg2, void *arg3);
NSInteger timeSort(id arg1, id arg2, void *arg3);

NSInteger sortAZ(id arg1, id arg2, void *arg3);
NSInteger sortAZInvite(id arg1, id arg2, void *arg3);
NSInteger sortAZInvites(id arg1, id arg2, void *arg3);

typedef struct {
	int pos;
	int code;
	int length;
} MOKNextEmoInfo;