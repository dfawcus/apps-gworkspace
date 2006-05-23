/* HtmlExtractor.h
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@dtedu.net>
 * Date: May 2006
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

#ifndef HTML_EXTRACTOR_H
#define HTML_EXTRACTOR_H

#include <Foundation/Foundation.h>

@protocol	StemmerProtocol

- (BOOL)setLanguage:(NSString *)lang;

- (NSString *)language;

- (NSArray *)stopWords;

- (NSString *)stemWord:(NSString *)word;

@end

@protocol	GMDSExtractorProtocol

- (BOOL)setMetadata:(NSDictionary *)mddict
            forPath:(NSString *)path
             withID:(int)path_id;

@end

@protocol	ExtractorsProtocol

- (id)initForExtractor:(id)extr;

- (NSString *)fileType;

- (NSArray *)pathExtensions;

- (BOOL)canExtractFromFileType:(NSString *)type
                 withExtension:(NSString *)ext
                    attributes:(NSDictionary *)attributes
                      testData:(NSData *)testdata;

- (BOOL)extractMetadataAtPath:(NSString *)path
                       withID:(int)path_id
                   attributes:(NSDictionary *)attributes
                 usingStemmer:(id)stemmer
                    stopWords:(NSSet *)stopwords;

@end


@interface HtmlExtractor: NSObject <ExtractorsProtocol>
{
  id extractor;
  NSArray *extensions;
  NSMutableCharacterSet *skipSet;
}

@end

#endif // HTML_EXTRACTOR_H
