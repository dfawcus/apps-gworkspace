/* Contents.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep GWorkspace application
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

#ifndef CONTENTS_H
#define CONTENTS_H

#include <Foundation/Foundation.h>

@class NSWorkspace;
@class NSImage;
@class NSView;
@class GenericView;

@interface Contents : NSObject
{
  IBOutlet id win;
  IBOutlet id mainBox;
  IBOutlet id topBox;
  IBOutlet id iconView;
  IBOutlet id titleField;
  IBOutlet id viewersBox;  

  NSView *noContsView;
  GenericView *genericView;

	NSMutableArray *viewers;
  id currentViewer;
  
  NSString *currentPath;
  
  NSImage *pboardImage;
  
  NSFileManager *fm;
	NSWorkspace *ws;
  
  id inspector;
}

- (id)initForInspector:(id)insp;

- (NSView *)inspView;

- (NSString *)winname;

- (void)activateForPaths:(NSArray *)paths;

- (id)viewerForPath:(NSString *)path;

- (id)viewerForDataOfType:(NSString *)type;

- (void)showContentsAt:(NSString *)path;

- (void)contentsReadyAt:(NSString *)path;

- (BOOL)canDisplayDataOfType:(NSString *)type;

- (void)showData:(NSData *)data 
          ofType:(NSString *)type;

- (void)dataContentsReadyForType:(NSString *)typeDescr
                         useIcon:(NSImage *)icon;

- (void)watchedPathDidChange:(NSDictionary *)info;

@end


@interface GenericView : NSView
{
  NSString *shComm;
  NSString *fileComm;
  NSTask *task;
  NSPipe *pipe;
  NSTextField *field;
  NSNotificationCenter *nc;
}

- (void)showInfoOfPath:(NSString *)path;

- (void)dataFromTask:(NSNotification *)notif;

@end

#endif // CONTENTS_H
