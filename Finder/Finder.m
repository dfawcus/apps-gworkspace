/* Finder.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep Finder application
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "Finder.h"
#include "FindView.h"
#include "FinderModulesProtocol.h"
#include "SearchPlacesScroll.h"
#include "SearchPlacesMatrix.h"
#include "LSFolder.h"
#include "StartAppWin.h"
#include "FSNBrowserCell.h"
#include "SearchResults.h"
#include "FSNode.h"
#include "FSNodeRep.h"
#include "Functions.h"
#include "config.h"
#include "GNUstep.h"

#define WINH (184.0)

#define FVIEWH (34.0)
#define BORDER (4.0)
#define HMARGIN (12.0)

#define ITMSLABY (3.0)
#define PLACESBOXY (24.0)
#define PLACESBOXH (116.0)
#define PLACEBUTTY (33.0)

#define SELECTION 0
#define PLACES 1

#define CELLS_HEIGHT (28.0)
#define ICON_SIZE NSMakeSize(24.0, 24.0)

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

static NSString *nibName = @"Finder";

static Finder *finder = nil;


@implementation Finder

+ (Finder *)finder
{
	if (finder == nil) {
		finder = [[Finder alloc] init];
	}	
  return finder;
}

+ (void)initialize
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject: @"Finder" 
               forKey: @"DesktopApplicationName"];
  [defaults setObject: @"finder" 
               forKey: @"DesktopApplicationSelName"];
  [defaults synchronize];
}

- (void)dealloc
{
  [[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
  DESTROY (workspaceApplication);
  DESTROY (ddbd);
  TEST_RELEASE (win);
  TEST_RELEASE (placesBox);
  TEST_RELEASE (addPlaceButt);
  TEST_RELEASE (removePlaceButt);
  TEST_RELEASE (modules);
  RELEASE (fviews);
  TEST_RELEASE (currentSelection);
  RELEASE (searchResults);
  RELEASE (lsFolders);
  RELEASE (startAppWin);
    
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    fviews = [NSMutableArray new];
    modules = nil;
    currentSelection = nil;
    searchResults = [NSMutableArray new];
    lsFolders = [NSMutableArray new];
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
    nc = [NSNotificationCenter defaultCenter];
    workspaceApplication = nil;
  }
  
  return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  NSUserDefaults *defaults;
  id defentry;
  NSDictionary *lastUsedModules;
  NSArray *usedNames;
  NSArray *unsortedModules;
  NSArray *usedModules;
  int index;
  int i;
  NSNumber *srh;
  NSRect wrect;
  NSRect brect;
  NSSize cs, ms;
  
  if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
    NSLog(@"failed to load %@!", nibName);
    [NSApp terminate: self];
  } 

  [win setTitle: NSLocalizedString(@"Finder", @"")];
  [win setDelegate: self];
  
  [win setFrameUsingName: @"finder"];
  wrect = [win frame];
  
  if (wrect.size.height != WINH) {
    if (wrect.size.height > WINH) {
      wrect.origin.y += (wrect.size.height - WINH);
    } else {
      wrect.origin.y -= (WINH - wrect.size.height);
    }
    wrect.size.height = WINH;
    [win setFrame: wrect display: NO];
  }
  
  RETAIN (placesBox);
  [placesBox removeFromSuperview];
  RETAIN (addPlaceButt);
  [addPlaceButt removeFromSuperview];
  RETAIN (removePlaceButt);
  [removePlaceButt removeFromSuperview];
  
  brect = [[(NSBox *)placesBox contentView] frame];
  placesScroll = [[SearchPlacesScroll alloc] initWithFrame: brect];
  [(NSBox *)placesBox setContentView: placesScroll];
  RELEASE (placesScroll);  
  
  placesMatrix = [[SearchPlacesMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
				            	            mode: NSListModeMatrix 
                             prototype: [[FSNBrowserCell new] autorelease]
			       							numberOfRows: 0 
                       numberOfColumns: 0
                            scrollView: placesScroll];
  [placesMatrix setTarget: self];
  [placesMatrix setAction: @selector(placesMatrixAction:)];
  [placesMatrix setIntercellSpacing: NSZeroSize];
  [placesMatrix setCellSize: NSMakeSize(1, CELLS_HEIGHT)];
  [placesMatrix setAutoscroll: YES];
	[placesMatrix setAllowsEmptySelection: YES];
  cs = [placesScroll contentSize];
  ms = [placesMatrix cellSize];
  ms.width = cs.width;
  CHECKSIZE (ms);
  [placesMatrix setCellSize: ms];
	[placesScroll setDocumentView: placesMatrix];	
  RELEASE (placesMatrix);

  [[FSNodeRep sharedInstance] setUseThumbnails: YES];
  
  defaults = [NSUserDefaults standardUserDefaults];
  
  defentry = [defaults objectForKey: @"saved_places"];
  
  if (defentry && [defentry isKindOfClass: [NSArray class]]) {
    for (i = 0; i < [defentry count]; i++) {
      NSString *srchplace = [defentry objectAtIndex: i];
  
      if ([fm fileExistsAtPath: srchplace]) {
        [self addSearchPlaceWithPath: srchplace];
      }
    }
  }
  
  [removePlaceButt setEnabled: ([[placesMatrix cells] count] != 0)];
    
  [[NSDistributedNotificationCenter defaultCenter] addObserver: self
                      selector: @selector(checkSearchPlaceRemoved:) 
                					name: @"GWFileSystemDidChangeNotification"
                				object: nil];    
  
  /* Internationalization */ 
  [searchLabel setStringValue: NSLocalizedString(@"Search in:", @"")];
  [wherePopUp removeAllItems];
  [wherePopUp insertItemWithTitle: NSLocalizedString(@"Current selection", @"")
                          atIndex: SELECTION];
  [wherePopUp insertItemWithTitle: NSLocalizedString(@"Specific places", @"")
                          atIndex: PLACES];
  [addPlaceButt setTitle: NSLocalizedString(@"Add", @"")];
  [removePlaceButt setTitle: NSLocalizedString(@"Remove", @"")];
  [itemsLabel setStringValue: NSLocalizedString(@"Search for items whose:", @"")];
  [findButt setTitle: NSLocalizedString(@"Search", @"")];
  
  searchPlaces = [defaults boolForKey: @"search_places"];
  if (searchPlaces) {
    [wherePopUp selectItemAtIndex: PLACES];
  }
    
  lastUsedModules = [defaults objectForKey: @"last_used_modules"];
  
  if ((lastUsedModules == nil) || ([lastUsedModules count] == 0)) {
    lastUsedModules = [NSDictionary dictionaryWithObjectsAndKeys:
         [NSNumber numberWithInt: 0], NSLocalizedString(@"name", @""),
         [NSNumber numberWithInt: 1], NSLocalizedString(@"kind", @""), 
         [NSNumber numberWithInt: 2], NSLocalizedString(@"size", @""), 
         [NSNumber numberWithInt: 3], NSLocalizedString(@"owner", @""), 
         [NSNumber numberWithInt: 4], NSLocalizedString(@"date created", @""), 
         [NSNumber numberWithInt: 5], NSLocalizedString(@"date modified", @""), 
         [NSNumber numberWithInt: 6], NSLocalizedString(@"contents", @""), 
         nil];
    usedNames = [NSArray arrayWithObject: NSLocalizedString(@"name", @"")];
  } else {
    usedNames = [lastUsedModules allKeys];
  }

  unsortedModules = [self loadModules];
  
  if ((unsortedModules == nil) || ([unsortedModules count] == 0)) {  
    NSRunAlertPanel(NSLocalizedString(@"error", @""), 
                    NSLocalizedString(@"No Finder modules! Quiting now.", @""), 
                    NSLocalizedString(@"OK", @""), nil, nil);                                     
    [NSApp terminate: self];
  }
  
  index = [usedNames count];

  for (i = 0; i < [unsortedModules count]; i++) {  
    id module = [unsortedModules objectAtIndex: i];  
    NSString *mname = [module moduleName];
    NSNumber *num = [lastUsedModules objectForKey: mname];
    
    if (num) {
      [module setIndex: [num intValue]];    
      [module setInUse: [usedNames containsObject: mname]];
    } else {
      [module setIndex: index];
      [module setInUse: NO];
      index++;
    }
  }

  modules = [[unsortedModules sortedArrayUsingSelector: @selector(compareModule:)] mutableCopy];
    
  usedModules = [self usedModules];
    
  for (i = 0; i < [usedModules count]; i++) {
    id module = [usedModules objectAtIndex: i];
    FindView *findView = [[FindView alloc] initForModules: modules];

    [findView setModule: module];
    
    if ([usedModules count] == [modules count]) {
      [findView setAddEnabled: NO];    
    }
    
    [[(NSBox *)findViewsBox contentView] addSubview: [findView mainBox]];
    [fviews insertObject: findView atIndex: [fviews count]];
    RELEASE (findView);
  }
    
  srh = [defaults objectForKey: @"search_res_h"];
  
  if (srh) {
    searchResh = [srh intValue];
  } else {
    searchResh = 0;
  } 
  
  startAppWin = [[StartAppWin alloc] init];

  fswatcher = nil;
  fswnotifications = YES;
  [self connectFSWatcher];

  ddbd = nil;
  ddbdactive = NO;
  [self connectDDBd];
  
  defentry = [defaults objectForKey: @"lsfolders_paths"];
  if (defentry) {
    for (i = 0; i < [defentry count]; i++) {
      NSString *lsfpath = [defentry objectAtIndex: i];
    
      if ([fm fileExistsAtPath: lsfpath]) {
        NSDictionary *lsfdict = [NSDictionary dictionaryWithContentsOfFile: lsfpath];

        if (lsfdict) {
          [self addLiveSearchFolderWithPath: lsfpath contentsInfo: lsfdict];
        
          NSLog(@"added lsf with path %@", lsfpath);
        }
      }
    }
  }
  
  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(fileSystemWillChange:) 
                					  name: @"GWFileSystemWillChangeNotification"
                					object: nil];

  [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				selector: @selector(fileSystemDidChange:) 
                					  name: @"GWFileSystemDidChangeNotification"
                					object: nil];
}

- (BOOL)application:(NSApplication *)application 
           openFile:(NSString *)fileName
{
  LSFolder *folder = [self lsfolderWithPath: fileName];

  if (folder == nil) {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: fileName];

    if (dict) {
      folder = [self addLiveSearchFolderWithPath: fileName contentsInfo: dict];

      NSLog(@"(open file) added lsf with path %@", fileName);
    }
  }

 // [folder sdlkfsldf

  NSLog(@"(open file) found lsf with path %@", fileName);

  return YES;
}

- (BOOL)applicationShouldTerminate:(NSApplication *)app 
{
  int i;

#define TEST_CLOSE(o, w) if ((o) && ([w isVisible])) [w close]
    
  for (i = 0; i < [searchResults count]; i++) {
    SearchResults *results = [searchResults objectAtIndex: i];
  
    [results stopSearch: nil];
    if ([[results win] isVisible]) {
      [[results win] close];
    }
  }

  [self updateDefaults];

  if (fswatcher) {
    NSConnection *fswconn = [(NSDistantObject *)fswatcher connectionForProxy];
  
    if ([fswconn isValid]) {
      [[NSNotificationCenter defaultCenter] removeObserver: self
	                        name: NSConnectionDidDieNotification
	                      object: fswconn];
      [fswatcher unregisterClient: (id <FSWClientProtocol>)self];  
      DESTROY (fswatcher);
    }
  }

  if (workspaceApplication) {
    NSConnection *c = [(NSDistantObject *)workspaceApplication connectionForProxy];
  
    if (c && [c isValid]) {
      [nc removeObserver: self
	                  name: NSConnectionDidDieNotification
	                object: c];
      DESTROY (workspaceApplication);
    }
  }
  
  TEST_CLOSE (startAppWin, [startAppWin win]);

  if (ddbd) {
    NSConnection *ddbdconn = [(NSDistantObject *)ddbd connectionForProxy];
  
    if (ddbdconn && [ddbdconn isValid]) {
      [[NSNotificationCenter defaultCenter] removeObserver: self
	                        name: NSConnectionDidDieNotification
	                      object: ddbdconn];
      DESTROY (ddbd);
    }
  }
    		
	return YES;
}

- (NSArray *)loadModules
{
  NSString *bundlesDir;
  BOOL isdir;
  NSMutableArray *bundlesPaths;
  NSArray *bpaths;
  NSMutableArray *loaded;
  int i;
  
  bundlesPaths = [NSMutableArray array];

  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
  bpaths = [self bundlesWithExtension: @"finder" inPath: bundlesDir];
  [bundlesPaths addObjectsFromArray: bpaths];

  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Finder"];  

  if (([fm fileExistsAtPath: bundlesDir isDirectory: &isdir] && isdir) == NO) {
    if ([fm createDirectoryAtPath: bundlesDir attributes: nil] == NO) {
      NSRunAlertPanel(NSLocalizedString(@"error", @""), 
             NSLocalizedString(@"Can't create the Finder user plugins directory! Quiting now.", @""), 
                                    NSLocalizedString(@"OK", @""), nil, nil);                                     
      return nil;
    }
  }

  bpaths = [self bundlesWithExtension: @"finder" inPath: bundlesDir];
  [bundlesPaths addObjectsFromArray: bpaths];

  loaded = [NSMutableArray array];
  
  for (i = 0; i < [bundlesPaths count]; i++) {
    NSString *bpath = [bundlesPaths objectAtIndex: i];
    NSBundle *bundle = [NSBundle bundleWithPath: bpath];
     
    if (bundle) {
			Class principalClass = [bundle principalClass];

			if ([principalClass conformsToProtocol: @protocol(FinderModulesProtocol)]) {	
	      CREATE_AUTORELEASE_POOL (pool);
        id module = [[principalClass alloc] initInterface];
	  		NSString *name = [module moduleName];
        BOOL exists = NO;	
        int j;
        			
				for (j = 0; j < [loaded count]; j++) {
					if ([name isEqual: [[loaded objectAtIndex: j] moduleName]]) {
            NSLog(@"duplicate module \"%@\" at %@", name, bpath);
						exists = YES;
						break;
					}
				}

				if (exists == NO) {
          [loaded addObject: module];
        }

	  		RELEASE ((id)module);			
        RELEASE (pool);		
			}
    }
  }
  
  return loaded;
}

- (NSArray *)usedModules
{
  NSMutableArray *used = [NSMutableArray array];
  int i;

  for (i = 0; i < [modules count]; i++) {
    id module = [modules objectAtIndex: i];
    
    if ([module used]) {
      [used addObject: module];
    }
  }
 
  return used;
}

- (id)firstUnusedModule
{
  int i;
  
  for (i = 0; i < [modules count]; i++) {
    id module = [modules objectAtIndex: i];
    
    if ([module used] == NO) {
      return module;
    }
  }
 
  return nil;
}

- (id)moduleWithName:(NSString *)mname
{
  int i;
  
  for (i = 0; i < [modules count]; i++) {
    id module = [modules objectAtIndex: i];
    
    if ([[module moduleName] isEqual: mname]) {
      return module;
    }
  }
 
  return nil;
}

- (void)addModule:(FindView *)aview
{
  NSArray *usedModules = [self usedModules];

  if ([usedModules count] < [modules count]) {
    int index = [fviews indexOfObjectIdenticalTo: aview];  
    id module = [self firstUnusedModule];
    FindView *findView = [[FindView alloc] initForModules: modules];
    int count;
    int i;
    
    [module setInUse: YES];
    [findView setModule: module];

    [[(NSBox *)findViewsBox contentView] addSubview: [findView mainBox]];
    [fviews insertObject: findView atIndex: index + 1];
    RELEASE (findView);
    
    count = [fviews count];
    
    for (i = 0; i < count; i++) {
      findView = [fviews objectAtIndex: i];

      [findView updateMenuForModules: modules];
      
      if (count == [modules count]) {
        [findView setAddEnabled: NO]; 
      }
      
      if (count > 1) {
        [findView setRemoveEnabled: YES]; 
      }
    }

    [self tile];
  }
}

- (void)removeModule:(FindView *)aview
{
  if ([fviews count] > 1) {
    int count;
    int i;

    [[aview module] setInUse: NO];
    [[aview mainBox] removeFromSuperview];
    [fviews removeObject: aview];
    
    count = [fviews count];
    
    for (i = 0; i < count; i++) {
      FindView *findView = [fviews objectAtIndex: i];
      
      [findView updateMenuForModules: modules];
      [findView setAddEnabled: YES]; 
      
      if (count == 1) {
        [findView setRemoveEnabled: NO]; 
      }
    }
    
    [self tile];
  }
}

- (void)findView:(FindView *)aview changeModuleTo:(NSString *)mname
{
  id module = [self moduleWithName: mname];

  if (module && ([aview module] != module)) {
    int i;

    [[aview module] setInUse: NO];
    [module setInUse: YES];
    [aview setModule: module];
    
    for (i = 0; i < [fviews count]; i++) {
      [[fviews objectAtIndex: i] updateMenuForModules: modules];
    }    
  }
}

- (NSArray *)bundlesWithExtension:(NSString *)extension 
													 inPath:(NSString *)path
{
  NSMutableArray *bundleList = [NSMutableArray array];
  NSEnumerator *enumerator;
  NSString *dir;
  BOOL isDir;
  
  if ((([fm fileExistsAtPath: path isDirectory: &isDir]) && isDir) == NO) {
		return nil;
  }
	  
  enumerator = [[fm directoryContentsAtPath: path] objectEnumerator];
  while ((dir = [enumerator nextObject])) {
    if ([[dir pathExtension] isEqualToString: extension]) {
			[bundleList addObject: [path stringByAppendingPathComponent: dir]];
		}
  }
  
  return bundleList;
}

- (void)tile
{
  NSRect wrect = [win frame];
  NSRect lbrect = [itemsLabel frame];
  NSRect vwsrect = [findViewsBox frame];
  float vwsheight = vwsrect.size.height;
  float hspace = FVIEWH + HMARGIN + BORDER;
  int count = [fviews count];
  int i;

  hspace = count * FVIEWH;  
  hspace = (hspace == 0) ? FVIEWH : hspace;
  hspace += BORDER;
  
  if (count) {
    hspace += HMARGIN;
  }

  if (vwsheight != hspace) {
    vwsrect.size.height = hspace;
    [findViewsBox setFrame: vwsrect];  
    
    lbrect.origin.y = (vwsrect.origin.y + vwsrect.size.height + ITMSLABY);
    [itemsLabel setFrame: lbrect]; 

    wrect.size.height += (hspace - vwsheight);
    wrect.origin.y -= (hspace - vwsheight);
    [win setFrame: wrect display: NO];
  }
    
  if (searchPlaces) {
    if ([placesBox superview] == nil) {
      NSView *cview = [win contentView];
      NSRect cvrect = [cview frame];
      NSRect addbrect = [addPlaceButt frame];
      NSRect rembrect = [removePlaceButt frame];
      
      addbrect.origin.y = cvrect.size.height - PLACEBUTTY;
      [addPlaceButt setFrame: addbrect];
      rembrect.origin.y = cvrect.size.height - PLACEBUTTY;
      [removePlaceButt setFrame: rembrect];

      [cview addSubview: placesBox];
      [cview addSubview: addPlaceButt];
      [cview addSubview: removePlaceButt];
      wrect.size.height += (PLACESBOXH);
      wrect.origin.y -= (PLACESBOXH);
      [win setFrame: wrect display: NO];
    }
    
  } else {
    if ([placesBox superview] != nil) {
      [placesBox removeFromSuperview];
      [addPlaceButt removeFromSuperview];
      [removePlaceButt removeFromSuperview];
      wrect.size.height -= (PLACESBOXH);
      wrect.origin.y += (PLACESBOXH);
      [win setFrame: wrect display: NO];
    }
  }

  if ([placesBox superview] != nil) {
    NSRect pscrect = [placesBox frame];
    pscrect.origin.y = (vwsrect.origin.y + vwsrect.size.height + PLACESBOXY);
    [placesBox setFrame: pscrect];
  }
  
  for (i = 0; i < count; i++) {  
    FindView *fview = [fviews objectAtIndex: i];
    NSBox *fvbox = [fview mainBox];
    NSRect fvbr = [fvbox frame];
    float posy = vwsrect.size.height - (FVIEWH * (i + 1)) - BORDER;
    
    if (fvbr.origin.y != posy) {
      fvbr.origin.y = posy;
      [fvbox setFrame: fvbr];
    }
  }
}

- (void)showWindow
{
  [win makeKeyAndOrderFront: nil];
  [self tile];
}

- (void)setSelectionData:(NSData *)data
{
  if (data) {
    NSArray *paths = [NSUnarchiver unarchiveObjectWithData: data];
    NSString *elmstr = NSLocalizedString(@"elements", @"");
    NSMenuItem *item = [wherePopUp itemAtIndex: SELECTION];
    NSString *title;
    
    ASSIGN (currentSelection, paths);
    
    if ([currentSelection count] == 1) {
      title = [currentSelection objectAtIndex: 0];
      title = [title lastPathComponent];
    } else {
      title = [NSString stringWithFormat: @"%i %@", [currentSelection count], elmstr];
    }
    
    [item setTitle: title];
    [wherePopUp setNeedsDisplay: YES];
  }
}

- (IBAction)chooseSearchPlacesType:(id)sender
{
  int index = [sender indexOfSelectedItem];

  if (index == PLACES) {
    if ([placesBox superview] == nil) {
      searchPlaces = YES;
      [self tile];
    }
  } else {
    if ([placesBox superview] != nil) {
      searchPlaces = NO;
      [self tile];
    }
  }
}

- (IBAction)addSearchPlaceFromDialog:(id)sender
{
	NSOpenPanel *openPanel;
  NSArray *filenames;
	int result;
  int i;
  
	openPanel = [NSOpenPanel openPanel];
	[openPanel setTitle: NSLocalizedString(@"open", @"")];	
	[openPanel setAllowsMultipleSelection: YES];
	[openPanel setCanChooseFiles: YES];
	[openPanel setCanChooseDirectories: YES];

	result = [openPanel runModalForDirectory: fixPath(@"/", 0) 
                                      file: nil 
							                       types: nil];
	if(result != NSOKButton) {
		return;
	}
	
  filenames = [openPanel filenames];

  for (i = 0; i < [filenames count]; i++) {
    [self addSearchPlaceWithPath: [filenames objectAtIndex: i]];
  }
}

- (void)addSearchPlaceFromPasteboard:(NSPasteboard *)pb
{
  NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
  int i;  

  for (i = 0; i < [sourcePaths count]; i++) {
    [self addSearchPlaceWithPath: [sourcePaths objectAtIndex: i]];
  }
}

- (void)addSearchPlaceWithPath:(NSString *)spath
{
  NSArray *cells = [placesMatrix cells];  
  int count = [cells count];
  BOOL found = NO;
  int i;

  for (i = 0; i < [cells count]; i++) {
    NSString *srchpath = [[cells objectAtIndex: i] path];
    
    if ([srchpath isEqual: spath]) {
      found = YES;
      break;
    }
  }
  
  if (found == NO) {
    FSNode *node = [FSNode nodeWithPath: spath];
    SEL compareSel = [[FSNodeRep sharedInstance] defaultCompareSelector];
    FSNBrowserCell *cell;
      
    if (count == 0) {
      [placesMatrix addColumn];
    } else {
      [placesMatrix insertRow: count];
    }

    cell = [placesMatrix cellAtRow: count column: 0];   
    [cell setNode: node];
    [cell setLeaf: YES]; 
    [cell setIcon];
    [placesMatrix sortUsingSelector: compareSel];
    [placesMatrix sizeToCells]; 
  }
}

- (IBAction)removeSearchPlaceButtAction:(id)sender
{
  NSArray *cells = [placesMatrix selectedCells];
  int i;

  for (i = 0; i < [cells count]; i++) {
    [self removeSearchPlaceWithPath: [[cells objectAtIndex: i] path]];
  } 
}

- (void)removeSearchPlaceWithPath:(NSString *)spath
{
  NSArray *cells = [placesMatrix cells];
  int i;

  for (i = 0; i < [cells count]; i++) {
    FSNBrowserCell *cell = [cells objectAtIndex: i];
  
    if ([[cell path] isEqual: spath]) {
      if ([cells count] == 1) {
        [placesMatrix removeColumn: 0];
      } else {
        int row, col;
        [placesMatrix getRow: &row column: &col ofCell: cell];
        [placesMatrix removeRow: row];
        [placesMatrix selectCellAtRow: 0 column: 0]; 
      }
      
      [placesMatrix sizeToCells]; 
      break;
    }
  }
  
  if ([[placesMatrix cells] count] == 0) {
    [removePlaceButt setEnabled: NO];
  }
}

- (NSArray *)searchPlacesPaths
{
  NSArray *cells = [placesMatrix cells];
  
  if (cells && [cells count]) {
    NSMutableArray *paths = [NSMutableArray array];  
    int i;
  
    for (i = 0; i < [cells count]; i++) {
      [paths addObject: [[cells objectAtIndex: i] path]];
    }
    
    return paths;
  }  

  return [NSArray array];
}

- (NSArray *)selectedSearchPlacesPaths
{
  NSArray *cells = [placesMatrix selectedCells];
  
  if (cells && [cells count]) {
    NSMutableArray *paths = [NSMutableArray array];  
    int i;
    
    RETAIN (cells);
    for (i = 0; i < [cells count]; i++) {
      NSString *path = [[cells objectAtIndex: i] path];
    
      if ([fm fileExistsAtPath: path]) {
        [paths addObject: path];
      } else {
        [self removeSearchPlaceWithPath: path];
      }
    }
    RELEASE (cells);
    
    return paths;
  }  

  return nil;
}

- (void)placesMatrixAction:(id)sender
{
  if ([[placesMatrix cells] count]) {
    [removePlaceButt setEnabled: YES];
  }
}

- (void)checkSearchPlaceRemoved:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSArray *files = [info objectForKey: @"files"];
  NSArray *placesPaths = [self searchPlacesPaths];
  NSMutableArray *deletedPlaces = [NSMutableArray array];
  int i, j;
  
  if ([operation isEqual: @"NSWorkspaceMoveOperation"] 
        || [operation isEqual: @"NSWorkspaceDestroyOperation"]
				|| [operation isEqual: @"NSWorkspaceRecycleOperation"]
				|| [operation isEqual: @"GWorkspaceRecycleOutOperation"]
				|| [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      NSString *fullPath = [source stringByAppendingPathComponent: fname];
      
      for (j = 0; j < [placesPaths count]; j++) {
        NSString *path = [placesPaths objectAtIndex: j];
      
        if ([fullPath isEqual: path]) {
          [deletedPlaces addObject: path];
        }
      }
    }
    
  } else if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    for (i = 0; i < [placesPaths count]; i++) {
      NSString *path = [placesPaths objectAtIndex: i];

      if ([source isEqual: path]) {
        [deletedPlaces addObject: path];
      }
    }
  }
  
  if ([deletedPlaces count]) {
    for (i = 0; i < [deletedPlaces count]; i++) {
      [self removeSearchPlaceWithPath: [deletedPlaces objectAtIndex: i]];
    }
  }
}

- (IBAction)startFind:(id)sender
{
  NSMutableDictionary *criteria = [NSMutableDictionary dictionary];
  NSArray *selection;
  int i;

  if (searchPlaces == NO) {
    if (currentSelection == nil) {
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"No selection!", @""), 
                      NSLocalizedString(@"OK", @""), 
                      nil, 
                      nil);  
      return;                                   
    } else {
      selection = currentSelection;
    }
    
  } else {
    selection = [self selectedSearchPlacesPaths];
  
    if (selection == nil) {
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"No selection!", @""), 
                      NSLocalizedString(@"OK", @""), 
                      nil, 
                      nil);  
      return;                              
    }
  }
  
  for (i = 0; i < [fviews count]; i++) {
    id module = [[fviews objectAtIndex: i] module]; 
    NSDictionary *dict = [module searchCriteria];

    if (dict) {
      [criteria setObject: dict 
                   forKey: NSStringFromClass([module class])];
    }
  }

  if ([criteria count]) {
    SearchResults *results = [SearchResults new];
    
    [searchResults addObject: results];
    RELEASE (results);
    
    [results activateForSelection: selection
               withSearchCriteria: criteria];  
    
  } else {
    NSRunAlertPanel(nil, 
                    NSLocalizedString(@"No search criteria!", @""), 
                    NSLocalizedString(@"OK", @""), 
                    nil, 
                    nil);                                     
  }
}

- (void)resultsWindowWillClose:(SearchResults *)results
{
  [searchResults removeObject: results];
}

- (void)setSearchResultsHeight:(int)srh
{
  searchResh = srh;
}

- (int)searchResultsHeight
{
  return searchResh;
}

- (void)openFoundSelection:(NSArray *)selection
{
  if (workspaceApplication == nil) {
    [self contactWorkspaceApp];
  }
  
  if (workspaceApplication) {
    int i;

    for (i = 0; i < [selection count]; i++) {
      FSNode *node = [selection objectAtIndex: i];

      if ([node isDirectory] || [node isMountPoint]) {
        if ([node isApplication]) {
          [ws launchApplication: [node path]];
        } else if ([node isPackage]) {
          [workspaceApplication openFile: [node path]];
        } else {
          [workspaceApplication selectFile: [node path] 
                  inFileViewerRootedAtPath: [node parentPath]];
        }        
      } else if ([node isPlain] || [node isExecutable]) {
        [workspaceApplication openFile: [node path]];    
      } else if ([node isApplication]) {
        [ws launchApplication: [node path]];    
      }
    }
  }
}

- (LSFolder *)addLiveSearchFolderWithPath:(NSString *)path
                             contentsInfo:(NSDictionary *)info
{
  LSFolder *folder = [self lsfolderWithPath: path];

  if (folder == nil) {
    FSNode *node = [FSNode nodeWithPath: path];
  
    folder = [[LSFolder alloc] initForNode: node];
    [lsFolders addObject: folder];
    RELEASE (folder);
  }
  
  return folder;
}

- (void)removeLiveSearchFolder:(LSFolder *)folder
{
  [lsFolders removeObject: folder];
}

- (LSFolder *)lsfolderWithNode:(FSNode *)node
{
  int i;
  
  for (i = 0; i < [lsFolders count]; i++) {
    LSFolder *folder = [lsFolders objectAtIndex: i];
    
    if ([[folder node] isEqual: node]) {
      return folder;
    }
  }
  
  return nil;
}

- (LSFolder *)lsfolderWithPath:(NSString *)path
{
  int i;
  
  for (i = 0; i < [lsFolders count]; i++) {
    LSFolder *folder = [lsFolders objectAtIndex: i];
    
    if ([[[folder node] path] isEqual: path]) {
      return folder;
    }
  }
  
  return nil;
}






- (void)fileSystemWillChange:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  int i;

  for (i = 0; i < [lsFolders count]; i++) {
    LSFolder *folder = [lsFolders objectAtIndex: i];
    FSNode *node = [folder node];
    
    if ([node involvedByFileOperation: info]) {
      [self removeWatcherForPath: [node path]];
      [folder setWatcherSuspended: YES];
      
      if ([node willBeValidAfterFileOperation: info] == NO) {
   //   [folder setLocked: YES];
      }
    }
  }

  NSLog(@"fileSystemWillChange");
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
  CREATE_AUTORELEASE_POOL(arp);
  NSDictionary *info = [notif userInfo];
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
  NSArray *origfiles = [info objectForKey: @"origfiles"];
  NSMutableArray *srcpaths = [NSMutableArray array];
  NSMutableArray *dstpaths = [NSMutableArray array];
  BOOL copy, move, remove; 
  int i, j, count;
  
  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    srcpaths = [NSArray arrayWithObject: source];
    dstpaths = [NSArray arrayWithObject: destination];
  } else {
    if ([operation isEqual: @"NSWorkspaceDuplicateOperation"]) { 
      for (i = 0; i < [files count]; i++) {
        NSString *fname = [origfiles objectAtIndex: i];
        [srcpaths addObject: [source stringByAppendingPathComponent: fname]];
        fname = [files objectAtIndex: i];
        [dstpaths addObject: [destination stringByAppendingPathComponent: fname]];
      }
    } else {  
      for (i = 0; i < [files count]; i++) {
        NSString *fname = [files objectAtIndex: i];
        [srcpaths addObject: [source stringByAppendingPathComponent: fname]];
        [dstpaths addObject: [destination stringByAppendingPathComponent: fname]];
      }
    }
  }

  copy = ([operation isEqual: @"NSWorkspaceCopyOperation"]
                || [operation isEqual: @"NSWorkspaceDuplicateOperation"]); 

  move = ([operation isEqual: @"NSWorkspaceMoveOperation"] 
                || [operation isEqual: @"GWorkspaceRenameOperation"]); 

  remove = ([operation isEqual: @"NSWorkspaceDestroyOperation"]
				        || [operation isEqual: @"NSWorkspaceRecycleOperation"]);
  
  count = [lsFolders count];
  
  for (i = 0; i < count; i++) {
    LSFolder *folder = [lsFolders objectAtIndex: i];
    FSNode *node = [folder node];
    FSNode *newnode = nil;
    BOOL found = NO;
    
    for (j = 0; j < [srcpaths count]; j++) {
      NSString *srcpath = [srcpaths objectAtIndex: j];
      NSString *dstpath = [dstpaths objectAtIndex: j];
      
      if (move || copy) {
        if ([[node path] isEqual: srcpath]) {
          if ([fm fileExistsAtPath: dstpath]) {
            newnode = [FSNode nodeWithPath: dstpath];
            found = YES;
          }
          break;
                  
        } else if ([node isSubnodeOfPath: srcpath]) {
          NSString *newpath = pathRemovingPrefix([node path], srcpath);

          newpath = [dstpath stringByAppendingPathComponent: newpath];
          
          if ([fm fileExistsAtPath: newpath]) {
            newnode = [FSNode nodeWithPath: newpath];
            found = YES;
          }
          break;
        }
        
      } else if (remove) {
        if ([[node path] isEqual: srcpath] || [node isSubnodeOfPath: srcpath]) {
          found = YES;
          break;
        }
      }
    }
    
    [folder setWatcherSuspended: NO];
    
    if (found) {
      if (move) {
      
        NSLog(@"moved lsf with path %@ to path %@", [node path], [newnode path]);
      
        [folder setNode: newnode];
        
      } else if (copy) {
        NSString *dictpath = [newnode path];
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: dictpath];

        if (dict) {
          [self addLiveSearchFolderWithPath: dictpath contentsInfo: dict];
        
        
          NSLog(@"added lsf with path %@", [newnode path]);
        
        }

      } else if (remove) {
        NSLog(@"removed lsf with path %@", [node path]);
      
        [self removeLiveSearchFolder: folder];
        count--;
        i--;
      }
    }
  }
  
  RELEASE (arp);
}

- (void)watchedPathDidChange:(NSData *)dirinfo
{
  NSDictionary *info = [NSUnarchiver unarchiveObjectWithData: dirinfo];
  NSString *event = [info objectForKey: @"event"];

  if ([event isEqual: @"GWWatchedFileDeleted"]) {
    LSFolder *folder = [self lsfolderWithPath: [info objectForKey: @"path"]];
    
    if (folder) {
      NSLog(@"removed (watcher) lsf with path %@", [[folder node] path]);
    
      [self removeLiveSearchFolder: folder];
    }
  }
}

- (void)addWatcherForPath:(NSString *)path
{
  if (fswnotifications) {
    [self connectFSWatcher];
    [fswatcher client: self addWatcherForPath: path];
  }
}

- (void)removeWatcherForPath:(NSString *)path
{
  if (fswnotifications) {
    [self connectFSWatcher];
    [fswatcher client: self removeWatcherForPath: path];
  }
}

- (void)connectFSWatcher
{
  if (fswatcher == nil) {
    id fsw = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                               host: @""];

    if (fsw) {
      NSConnection *c = [fsw connectionForProxy];

	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(fswatcherConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: c];
      
      fswatcher = fsw;
	    [fswatcher setProtocolForProxy: @protocol(FSWatcherProtocol)];
      RETAIN (fswatcher);
                                   
	    [fswatcher registerClient: (id <FSWClientProtocol>)self];
      
	  } else {
	    static BOOL recursion = NO;
	    static NSString	*cmd = nil;

	    if (recursion == NO) {
        if (cmd == nil) {
            cmd = RETAIN ([[NSSearchPathForDirectoriesInDomains(
                      GSToolsDirectory, NSSystemDomainMask, YES) objectAtIndex: 0]
                            stringByAppendingPathComponent: @"fswatcher"]);
		    }
      }
	  
      if (recursion == NO && cmd != nil) {
        int i;
        
        [startAppWin showWindowWithTitle: @"Finder"
                                 appName: @"fswatcher"
                            maxProgValue: 40.0];

	      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
        DESTROY (cmd);
        
        for (i = 1; i <= 40; i++) {
          [startAppWin updateProgressBy: 1.0];
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
                           
          fsw = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                                  host: @""];                  
          if (fsw) {
            [startAppWin updateProgressBy: 40.0 - i];
            break;
          }
        }
        
        [[startAppWin win] close];
        
	      recursion = YES;
	      [self connectFSWatcher];
	      recursion = NO;
        
	    } else { 
        DESTROY (cmd);
	      recursion = NO;
        fswnotifications = NO;
        NSRunAlertPanel(nil,
                NSLocalizedString(@"unable to contact fswatcher\nfswatcher notifications disabled!", @""),
                NSLocalizedString(@"Ok", @""),
                nil, 
                nil);  
      }
	  }
  }
}

- (void)fswatcherConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [[NSNotificationCenter defaultCenter] removeObserver: self
	                    name: NSConnectionDidDieNotification
	                  object: connection];

  NSAssert(connection == [fswatcher connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (fswatcher);
  fswatcher = nil;

  if (NSRunAlertPanel(nil,
                    NSLocalizedString(@"The fswatcher connection died.\nDo you want to restart it?", @""),
                    NSLocalizedString(@"Yes", @""),
                    NSLocalizedString(@"No", @""),
                    nil)) {
    [self connectFSWatcher];                
  } else {
    fswnotifications = NO;
    NSRunAlertPanel(nil,
                    NSLocalizedString(@"fswatcher notifications disabled!", @""),
                    NSLocalizedString(@"Ok", @""),
                    nil, 
                    nil);  
  }
}

- (void)connectDDBd
{
  if (ddbd == nil) {
    id db = [NSConnection rootProxyForConnectionWithRegisteredName: @"ddbd" 
                                                              host: @""];

    if (db) {
      NSConnection *c = [db connectionForProxy];

	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(ddbdConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: c];
      
      ddbd = db;
	    [ddbd setProtocolForProxy: @protocol(DDBdProtocol)];
      RETAIN (ddbd);
      ddbdactive = [ddbd dbactive];
                                         
	  } else {
	    static BOOL recursion = NO;
	    static NSString	*cmd = nil;

	    if (recursion == NO) {
        if (cmd == nil) {
            cmd = RETAIN ([[NSSearchPathForDirectoriesInDomains(
                      GSToolsDirectory, NSSystemDomainMask, YES) objectAtIndex: 0]
                            stringByAppendingPathComponent: @"ddbd"]);
		    }
      }
	  
      if (recursion == NO && cmd != nil) {
        int i;
        
        [startAppWin showWindowWithTitle: @"Finder"
                                 appName: @"ddbd"
                            maxProgValue: 40.0];

	      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
        DESTROY (cmd);
        
        for (i = 1; i <= 40; i++) {
          [startAppWin updateProgressBy: 1.0];
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
                           
          db = [NSConnection rootProxyForConnectionWithRegisteredName: @"ddbd" 
                                                                 host: @""];                  
          if (db) {
            [startAppWin updateProgressBy: 40.0 - i];
            break;
          }
        }
        
        [[startAppWin win] close];
        
	      recursion = YES;
	      [self connectDDBd];
	      recursion = NO;
        
	    } else { 
        DESTROY (cmd);
	      recursion = NO;
        ddbdactive = NO;
        NSRunAlertPanel(nil,
                NSLocalizedString(@"unable to contact ddbd.", @""),
                NSLocalizedString(@"Ok", @""),
                nil, 
                nil);  
      }
	  }
  }
}

- (void)ddbdConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [[NSNotificationCenter defaultCenter] removeObserver: self
	                    name: NSConnectionDidDieNotification
	                  object: connection];

  NSAssert(connection == [ddbd connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (ddbd);
  ddbd = nil;
  ddbdactive = NO;
  
  NSRunAlertPanel(nil,
                  NSLocalizedString(@"ddbd connection died.", @""),
                  NSLocalizedString(@"Ok", @""),
                  nil,
                  nil);                
}

- (BOOL)ddbdactive
{
  return ddbdactive;
}

- (void)ddbdInsertPath:(NSString *)path
{
  if (ddbdactive) {
    [ddbd insertPath: path];
  }
}

- (void)ddbdRemovePath:(NSString *)path
{
  if (ddbdactive) {
    [ddbd removePath: path];
  }
}

- (NSString *)ddbdGetAnnotationsForPath:(NSString *)path
{
  if (ddbdactive) {
    return [ddbd annotationsForPath: path];
  }
  
  return nil;
}

- (void)ddbdSetAnnotations:(NSString *)annotations
                   forPath:(NSString *)path
{
  if (ddbdactive) {
    [ddbd setAnnotations: annotations forPath: path];
  }
}

- (NSString *)ddbdGetFileTypeForPath:(NSString *)path
{
  if (ddbdactive) {
    return [ddbd fileTypeForPath: path];
  }
  
  return nil;
}

- (void)ddbdSetFileType:(NSString *)type
                forPath:(NSString *)path
{
  if (ddbdactive) {
    [ddbd setFileType: type forPath: path];
  }
}

- (NSString *)ddbdGetModificationDateForPath:(NSString *)path;
{
  if (ddbdactive) {
    return [ddbd modificationDateForPath: path];
  }
  
  return nil;
}

- (void)ddbdSetModificationDate:(NSString *)datedescr
                        forPath:(NSString *)path
{
  if (ddbdactive) {
    [ddbd setModificationDate: datedescr forPath: path];
  }  
}

- (NSData *)ddbdGetIconDataForPath:(NSString *)path
{
  if (ddbdactive) {
    return [ddbd iconDataForPath: path];
  }
  
  return nil;
}

- (void)ddbdSetIconData:(NSData *)data
                forPath:(NSString *)path
{
  if (ddbdactive) {
    [ddbd setIconData: data forPath: path];
  }
}

- (void)contactWorkspaceApp
{
  id app = nil;

  if (workspaceApplication == nil) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *appName = [defaults stringForKey: @"GSWorkspaceApplication"];

    if (appName == nil) {
      appName = @"GWorkspace";
    }

    app = [NSConnection rootProxyForConnectionWithRegisteredName: appName
                                                            host: @""];

    if (app) {
      NSConnection *c = [app connectionForProxy];

	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(workspaceAppConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: c];

      workspaceApplication = app;
      [workspaceApplication setProtocolForProxy: @protocol(workspaceAppProtocol)];
      RETAIN (workspaceApplication);
      
	  } else {
	    static BOOL recursion = NO;
	  
      if (recursion == NO) {
        int i;

        [startAppWin showWindowWithTitle: @"Finder"
                                 appName: @"GWorkspace"
                            maxProgValue: 80.0];
        
        [ws launchApplication: appName];

        for (i = 1; i <= 80; i++) {
          [startAppWin updateProgressBy: 1.0];
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
          app = [NSConnection rootProxyForConnectionWithRegisteredName: appName 
                                                                   host: @""];                  
          if (app) {
            break;
          }
        }
        
        [[startAppWin win] close];
        
	      recursion = YES;
	      [self contactWorkspaceApp];
	      recursion = NO;
        
	    } else { 
	      recursion = NO;
        NSRunAlertPanel(nil,
                NSLocalizedString(@"unable to contact the workspace application!", @""),
                NSLocalizedString(@"Ok", @""),
                nil, 
                nil);  
      }
	  }
  }
}

- (void)workspaceAppConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  NSAssert(connection == [workspaceApplication connectionForProxy],
		                                      NSInternalInconsistencyException);
  DESTROY (workspaceApplication);
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSMutableArray *lsfpaths = [NSMutableArray array];
  NSArray *cells = [placesMatrix cells];
  NSRect savedwrect = [win frame];
  NSRect wrect = savedwrect;
  int i;

  [defaults setBool: ([placesBox superview] != nil)
             forKey: @"search_places"];

  if (cells && [cells count]) {
    NSMutableArray *savedPlaces = [NSMutableArray array];
    
    for (i = 0; i < [cells count]; i++) {
      NSString *srchpath = [[cells objectAtIndex: i] path];
    
      if ([fm fileExistsAtPath: srchpath]) {
        [savedPlaces addObject: srchpath];
      }
    }
    
    [defaults setObject: savedPlaces forKey: @"saved_places"];
  }

  for (i = 0; i < [fviews count]; i++) {
    FindView *fview = [fviews objectAtIndex: i];
    id module = [fview module]; 
    [dict setObject: [NSNumber numberWithInt: i]
             forKey: [module moduleName]];    
  }

  [defaults setObject: dict forKey: @"last_used_modules"];   
  
  [defaults setObject: [NSNumber numberWithInt: searchResh] 
               forKey: @"search_res_h"];    
   
  if (savedwrect.size.height != WINH) {
    if (savedwrect.size.height > WINH) {
      savedwrect.origin.y += (savedwrect.size.height - WINH);
    } else {
      savedwrect.origin.y -= (WINH - savedwrect.size.height);
    }
    savedwrect.size.height = WINH;
    [win setFrame: savedwrect display: NO];
  }

  [win saveFrameUsingName: @"finder"];
  [win setFrame: wrect display: NO];
  
  for (i = 0; i < [lsFolders count]; i++) {
    LSFolder *folder = [lsFolders objectAtIndex: i];
    FSNode *node = [folder node];
    
    if ([node isValid]) {
      [lsfpaths addObject: [node path]];
    }  
  }
  
  [defaults setObject: lsfpaths forKey: @"lsfolders_paths"];
  
  [defaults synchronize];  
}

- (BOOL)windowShouldClose:(id)sender
{
  [self updateDefaults];
	return YES;
}


//
// Menu Operations
//
- (void)showFindWindow:(id)sender
{
  [win makeKeyAndOrderFront: nil];
  [self tile];
}

- (void)showPreferences:(id)sender
{
//  [preferences activate];
}

- (void)showInfo:(id)sender
{
  NSMutableDictionary *d = AUTORELEASE ([NSMutableDictionary new]);
  [d setObject: @"Finder" forKey: @"ApplicationName"];
  [d setObject: NSLocalizedString(@"-----------------------", @"")
      	forKey: @"ApplicationDescription"];
  [d setObject: @"Finder 0.7" forKey: @"ApplicationRelease"];
  [d setObject: @"04 2004" forKey: @"FullVersionID"];
  [d setObject: [NSArray arrayWithObjects: @"Enrico Sersale <enrico@imago.ro>.", nil]
        forKey: @"Authors"];
  [d setObject: NSLocalizedString(@"See http://www.gnustep.it/enrico/gworkspace", @"") forKey: @"URL"];
  [d setObject: @"Copyright (C) 2004 Free Software Foundation, Inc."
        forKey: @"Copyright"];
  [d setObject: NSLocalizedString(@"Released under the GNU General Public License 2.0", @"")
        forKey: @"CopyrightDescription"];
  
#ifdef GNUSTEP	
  [NSApp orderFrontStandardInfoPanelWithOptions: d];
#else
	[NSApp orderFrontStandardAboutPanel: d];
#endif
}

- (void)closeMainWin:(id)sender
{
  [[[NSApplication sharedApplication] keyWindow] performClose: sender];
}

#ifndef GNUSTEP
- (void)terminate:(id)sender
{
  [NSApp terminate: self];
}
#endif


//
// DesktopApplication protocol
//
- (void)selectionChanged:(NSArray *)newsel
{
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
}

- (void)openSelectionWithApp:(id)sender
{
}

- (void)performFileOperation:(NSDictionary *)opinfo
{
}

- (void)concludeRemoteFilesDragOperation:(NSData *)opinfo
                             atLocalPath:(NSString *)localdest
{
}

- (NSString *)trashPath
{
  return [NSString string];
}

- (id)workspaceApplication
{
  if (workspaceApplication == nil) {
    [self contactWorkspaceApp];
  }
  return workspaceApplication;
}

@end








