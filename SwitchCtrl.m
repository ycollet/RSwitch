#import "SwitchCtrl.h"

@interface SwitchCtrl (Private)
NSArray *versions = nil;
NSArray *desc = nil;
BOOL finishedLoading = NO;

- (void) reloadVersions;
@end

@implementation SwitchCtrl

NSString *where = @"/Library/Frameworks/R.framework/Versions";

- (IBAction)rediscover:(id)sender
{
	[self reloadVersions];
}

/* awake */

- (void) awakeFromNib {
	[self reloadVersions];
	finishedLoading = YES;
}

// fn is now a path to R_HOME. Uses bin/R (for older R) or Rversion.h header
static NSString *getVersionString(NSString *fn) {
	char buf[512];
	FILE *f = fopen([[fn stringByAppendingString:@"/bin/R"] UTF8String],"r");
	if (!f) return @"<incomplete installation>";
	buf[511]=0;
	while (!feof(f) && fgets(buf,511,f)) {
		char *c = strstr(buf,"version=\"");
		if (c) {
			char *d = c;
			while (*d) d++;
			d--; while (d > c+10 && (*d=='.' || *d=='\n' || *d=='\r' || *d==' ')) { *d=0; d--; };
			fclose(f);
			return [NSString stringWithUTF8String:c+9];
		}
	}
	fclose(f);
	// bin/R doesn't contain version="" - try headers - it's messy, though
	f = fopen([[fn stringByAppendingString:@"/include/i386/Rversion.h"] UTF8String], "r");
	if (!f) // possibly not multi-arch -- note that this won't work for multi-arch as it's jsut a stub
		f = fopen([[fn stringByAppendingString:@"/include/Rversion.h"] UTF8String], "r");
	if (f) {
		NSString *ver = @"";
		while (!feof(f) && fgets(buf, 511, f)) {
			int maj = 1;
			char *c = strstr(buf, "R_MAJOR");
			if (!c) {
				c = strstr(buf, "R_MINOR");
				maj = 0;
			}
			if (c) {
				char *anchor;
				while (*c && *c != '\"') c++;
				if (*c) c++;
				anchor = c;
				while (*c && *c != '\"') c++;
				*c = 0;
				ver = [ver stringByAppendingFormat:@"%s%s", maj ? "" : ".", anchor];
			}
		}
		fclose(f);
		if ([ver length] > 0)
			return ver;
	}
	return @"<unknown>";
}

- (void) reloadVersions {
	NSArray *cont = [[NSFileManager defaultManager] directoryContentsAtPath:where];
	if (cont) {
		NSMutableArray *ma = [[NSMutableArray alloc] initWithCapacity:[cont count]];
		if (desc) [desc release];
		desc = [[NSMutableArray alloc] initWithCapacity:[cont count]];
		NSEnumerator *enumerator = [cont objectEnumerator];
		NSString *cur = [[NSFileManager defaultManager] pathContentOfSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/Current", where]];
		NSString *ver;
		while (ver = (NSString*) [enumerator nextObject]) {
			NSString *rsh = [NSString stringWithFormat:@"%@/%@/Resources", where, ver];
			if (![ver isEqualToString:@"Current"] && [[NSFileManager defaultManager] fileExistsAtPath:rsh]) {
				[ma addObject:ver];
				[(NSMutableArray*)desc addObject: getVersionString(rsh)];
			}
		}
		if (versions) [versions release];
		versions = ma;
		
		[list reloadData];

		if (cur) {
			int cp = [versions indexOfObject:cur];
			if (cp != NSNotFound) [list selectRow:cp byExtendingSelection:NO];
		}
	}
}

/* selection */

- (void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
	int nr = [list numberOfRows];
	int sel = -1;
	if (nr>0) {
		sel = [list selectedRow];
		if (finishedLoading && sel>=0 && sel<nr) {
			NSString *curl = [NSString stringWithFormat:@"%@/Current", where];
			NSString *new = [versions objectAtIndex:sel];
			[[NSFileManager defaultManager] removeFileAtPath:curl handler:nil];
			[[NSFileManager defaultManager] createSymbolicLinkAtPath:curl pathContent:new];
			NSLog(@"Requested change of link %@ to %@", curl, new);
		}
	}
	NSLog(@"Did change, nr=%d, sel=%d, finished=%d", nr, sel, finishedLoading);
}

/* dataSource callbacks */

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	NSArray *ac = nil;
	if ([[aTableColumn identifier] isEqual:@"desc"]) ac = desc;
	if ([[aTableColumn identifier] isEqual:@"version"]) ac = versions;
	if (!ac) return nil;
    NSParameterAssert(rowIndex >= 0 && rowIndex < [ac count]);
    return [ac objectAtIndex:rowIndex];
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return desc?[desc count]:0;
}

/* window callbacks */

- (BOOL)windowShouldClose:(id)sender {
	ExitToShell();
	return YES;
}


@end
