//
//  untitled.m
//  Blip
//
//  Created by G V on 16.05.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MOKutils.h"
#import "MOKMessage.h"

NSInteger timestampSort(id arg1, id arg2, void *arg3) {
	MOKMessage *m1 = arg1;
	MOKMessage *m2 = arg2;
	if (m1.timestampOrder == m2.timestampOrder) {
		return 0;
	}
	return m1.timestampOrder > m2.timestampOrder ? 1 : -1;
}