/* FileOpInfo.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep Operation application
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

#ifndef FILE_OP_INFO_H
#define FILE_OP_INFO_H

#include <Foundation/Foundation.h>

@class FileOpExecutor;
@class ProgressView;


@protocol FileOpInfoProtocol

- (void)registerExecutor:(id)anObject;
                            
- (int)requestUserConfirmationWithMessage:(NSString *)message 
                                    title:(NSString *)title;

- (int)showErrorAlertWithMessage:(NSString *)message;

- (void)setNumFiles:(int)n;

- (void)setProgIndicatorValue:(int)n;

- (void)sendDidChangeNotification;

- (oneway void)endOperation;

@end


@protocol FileOpExecutorProtocol

+ (void)setPorts:(NSArray *)thePorts;

- (void)setFileop:(NSArray *)thePorts;

- (BOOL)setOperation:(NSData *)opinfo;

- (BOOL)checkSameName;

- (void)setOnlyOlder;

- (oneway void)calculateNumFiles;

- (oneway void)performOperation;

- (NSData *)processedFiles;

- (oneway void)Pause;

- (oneway void)Stop;

- (BOOL)isPaused;

- (void)done;

- (oneway void)exitThread;

@end


@interface FileOpInfo: NSObject
{
  NSString *type;
  NSString *source;
  NSString *destination;
  NSArray *files;
  int ref;
  
  NSMutableDictionary *operationDict;
  NSMutableArray *notifNames;
  
  BOOL confirm;
  BOOL showwin;
  BOOL opdone;
  NSConnection *execconn;
  id <FileOpExecutorProtocol> executor;
  NSNotificationCenter *nc;
  NSNotificationCenter *dnc;
  NSFileManager *fm;
    
  id controller;  

  IBOutlet id win;
  IBOutlet id fromLabel;
  IBOutlet id fromField;
  IBOutlet id toLabel;
  IBOutlet id toField;
  IBOutlet id progBox;
  IBOutlet id progInd;
  ProgressView *progView;
  IBOutlet id pauseButt;
  IBOutlet id stopButt;  
}

+ (id)operationOfType:(NSString *)tp
                  ref:(int)rf
               source:(NSString *)src
          destination:(NSString *)dst
                files:(NSArray *)fls
         confirmation:(BOOL)conf
            usewindow:(BOOL)uwnd
              winrect:(NSRect)wrect
           controller:(id)cntrl;

- (id)initWithOperationType:(NSString *)tp
                        ref:(int)rf
                     source:(NSString *)src
                destination:(NSString *)dst
                      files:(NSArray *)fls
               confirmation:(BOOL)conf
                  usewindow:(BOOL)uwnd
                    winrect:(NSRect)wrect
                 controller:(id)cntrl;

- (void)startOperation;

- (void)threadWillExit:(NSNotification *)notification;

- (int)requestUserConfirmationWithMessage:(NSString *)message 
                                    title:(NSString *)title;

- (int)showErrorAlertWithMessage:(NSString *)message;

- (IBAction)pause:(id)sender;

- (IBAction)stop:(id)sender;

- (void)showProgressWin;

- (void)setNumFiles:(int)n;

- (void)setProgIndicatorValue:(int)n;

- (void)endOperation;

- (void)sendWillChangeNotification;

- (void)sendDidChangeNotification;

- (void)registerExecutor:(id)anObject;

- (void)connectionDidDie:(NSNotification *)notification;

- (NSString *)type;

- (NSString *)source;

- (NSString *)destination;

- (NSArray *)files;

- (int)ref;

- (BOOL)showsWindow;

- (NSWindow *)win;

- (NSRect)winRect;

@end 


@interface FileOpExecutor: NSObject
{
	NSString *operation;
	NSString *source;
	NSString *destination;
	NSMutableArray *files;
	NSMutableArray *procfiles;
	NSDictionary *fileinfo;
	NSString *filename;
  int fcount;
  float progstep;
  int stepcount;
	BOOL stopped;
	BOOL paused;
	BOOL canupdate;
  BOOL samename;
  BOOL onlyolder;
  NSFileManager *fm;
  NSConnection *fopConn;
  id <FileOpInfoProtocol> fileOp;
}

+ (void)setPorts:(NSArray *)thePorts;

- (void)setFileop:(NSArray *)thePorts;

- (BOOL)setOperation:(NSData *)opinfo;

- (BOOL)checkSameName;

- (void)setOnlyOlder;

- (void)calculateNumFiles;

- (void)performOperation;

- (NSData *)processedFiles;

- (void)Pause;

- (void)Stop;

- (BOOL)isPaused;

- (void)done;

- (void)exitThread;

- (void)doMove;

- (void)doCopy;

- (void)doLink;

- (void)doRemove;

- (void)doDuplicate;

- (void)doRename;

- (void)doNewFolder;

- (void)doNewFile;

- (void)doTrash;

- (BOOL)removeExisting:(NSDictionary *)info;

@end 


@interface ProgressView : NSView 
{
  NSImage *image;
  float orx;
  float rfsh;
  NSTimer *progTimer;
}

- (id)initWithFrame:(NSRect)frameRect 
    refreshInterval:(float)refresh;

- (void)start;

- (void)stop;

- (void)animate:(id)sender;

@end

#endif // FILE_OP_INFO_H
