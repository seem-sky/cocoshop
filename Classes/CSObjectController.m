/*
 * cocoshop
 *
 * Copyright (c) 2011 Andrew
 * Copyright (c) 2011 Stepan Generalov
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#import "CSObjectController.h"
#import "CSModel.h"
#import "CSSprite.h"
#import "CSMainLayer.h"
#import "cocoshopAppDelegate.h"
#import "CSTableViewDataSource.h"
#import "DebugLog.h"
#import "NSString+RelativePath.h"

@implementation CSObjectController

@synthesize modelObject=modelObject_;
@synthesize mainLayer=mainLayer_;
@synthesize spriteTableView=spriteTableView_;
@synthesize spriteInfoView = spriteInfoView_;
@synthesize backgroundInfoView = backgroundInfoView_;
@synthesize projectFilename = projectFilename_;

#pragma mark Init / DeInit

- (void)awakeFromNib
{
	// add a data source to the table view
	NSMutableArray *spriteArray = [modelObject_ spriteArray];
	
	@synchronized(spriteArray)
	{
		dataSource_ = [[CSTableViewDataSource dataSourceWithArray:spriteArray] retain];
	}
	[spriteTableView_ setDataSource:dataSource_];
	
	// listen to change in table view
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(spriteTableSelectionDidChange:) name:NSTableViewSelectionDidChangeNotification object:nil];
	
	// listen to notification when we deselect the sprite
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeSelectedSprite:) name:@"didChangeSelectedSprite" object:nil];
	
	// listen to rename in table view
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(spriteTableSelectionDidRename:) name:@"didRenameSelectedSprite" object:nil];

	// Disable Sprite Info for no Sprites at the beginning
	[self didChangeSelectedSprite:nil];
	
	// This will make panels less distracting
	[infoPanel_ setBecomesKeyOnlyIfNeeded: YES];
	[spritesPanel_ setBecomesKeyOnlyIfNeeded: YES];
}

- (void)dealloc
{
	self.projectFilename = nil;
	self.spriteInfoView = nil;
	self.backgroundInfoView = nil;
	
	[self setMainLayer:nil];
	[dataSource_ release];
	[super dealloc];
}

- (void)setMainLayer:(CSMainLayer *)view
{
	// release old view, set the new view to mainLayer_ and
	// set the view's controller to self
	if(view != mainLayer_)
	{
		[view retain];
		[mainLayer_ release];
		mainLayer_ = view;
		[view setController:self];
		
		// Using ivar, cause IB sucks
		showBordersMenuItem_.state = (mainLayer_.showBorders) ? NSOnState : NSOffState;
	}
	
	
}

#pragma mark Values Observer

- (void)registerAsObserver
{
	[modelObject_ addObserver:self forKeyPath:@"stageWidth" options:NSKeyValueObservingOptionNew context:NULL];
	[modelObject_ addObserver:self forKeyPath:@"stageHeight" options:NSKeyValueObservingOptionNew context:NULL];
	
	[modelObject_ addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:NULL];
	[modelObject_ addObserver:self forKeyPath:@"posX" options:NSKeyValueObservingOptionNew context:NULL];
	[modelObject_ addObserver:self forKeyPath:@"posY" options:NSKeyValueObservingOptionNew context:NULL];
	[modelObject_ addObserver:self forKeyPath:@"posZ" options:NSKeyValueObservingOptionNew context:NULL];
	[modelObject_ addObserver:self forKeyPath:@"anchorX" options:NSKeyValueObservingOptionNew context:NULL];
	[modelObject_ addObserver:self forKeyPath:@"anchorY" options:NSKeyValueObservingOptionNew context:NULL];
	[modelObject_ addObserver:self forKeyPath:@"scaleX" options:NSKeyValueObservingOptionNew context:NULL];
	[modelObject_ addObserver:self forKeyPath:@"scaleY" options:NSKeyValueObservingOptionNew context:NULL];
	[modelObject_ addObserver:self forKeyPath:@"flipX" options:NSKeyValueObservingOptionNew context:NULL];
	[modelObject_ addObserver:self forKeyPath:@"flipY" options:NSKeyValueObservingOptionNew context:NULL];
	[modelObject_ addObserver:self forKeyPath:@"opacity" options:NSKeyValueObservingOptionNew context:NULL];
	[modelObject_ addObserver:self forKeyPath:@"color" options:NSKeyValueObservingOptionNew context:NULL];
	[modelObject_ addObserver:self forKeyPath:@"relativeAnchor" options:NSKeyValueObservingOptionNew context:NULL];
	[modelObject_ addObserver:self forKeyPath:@"rotation" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)unregisterForChangeNotification
{
//	[modelObject_ removeObserver:self forKeyPath:@"name"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	DebugLog(@"keyPath  = %@", keyPath);
	
	if( [keyPath isEqualToString:@"name"] )
	{
		CSSprite *sprite = [modelObject_ selectedSprite];
		if(sprite)
		{
			NSString *currentName = [sprite name];
			NSString *newName = [modelObject_ name];
			if( ![currentName isEqualToString:newName] )
			{
				[sprite setName:newName];
				[self ensureUniqueNameForSprite:sprite];
				[nameField_ setStringValue:[sprite name]];
			}
		}
	}
	else if( [keyPath isEqualToString:@"posX"] )
	{
		CSSprite *sprite = [modelObject_ selectedSprite];
		if(sprite)
		{
			CGPoint currentPos = [sprite position];
			currentPos.x = [modelObject_ posX];
			[sprite setPosition:currentPos];
		}
		else
		{
			CGPoint currentPos = [[modelObject_ backgroundLayer] position];
			currentPos.x = [modelObject_ posX];
			[[modelObject_ backgroundLayer] setPosition:currentPos];
		}

	}
	else if( [keyPath isEqualToString:@"posY"] )
	{
		CSSprite *sprite = [modelObject_ selectedSprite];
		if(sprite)
		{
			CGPoint currentPos = [sprite position];
			currentPos.y = [modelObject_ posY];
			[sprite setPosition:currentPos];
		}
		else
		{
			CGPoint currentPos = [[modelObject_ backgroundLayer] position];
			currentPos.y = [modelObject_ posY];
			[[modelObject_ backgroundLayer] setPosition:currentPos];
		}

	}
	else if( [keyPath isEqualToString:@"posZ"] )
	{
		// Reorder Z order
		CSSprite *sprite = [modelObject_ selectedSprite];
		if(sprite)
		{
			CGFloat currentZ = [sprite zOrder];
			currentZ = [modelObject_ posZ];
			[[sprite parent] reorderChild: sprite z: currentZ ];
		}
	}
	else if( [keyPath isEqualToString:@"anchorX"] )
	{
		CSSprite *sprite = [modelObject_ selectedSprite];
		if(sprite)
		{
			CGPoint currentAnchor = [sprite anchorPoint];
			currentAnchor.x = [modelObject_ anchorX];
			[sprite setAnchorPoint:currentAnchor];
		}
		else
		{
			CGPoint currentAnchor = [[modelObject_ backgroundLayer] anchorPoint];
			currentAnchor.x = [modelObject_ anchorX];
			[[modelObject_ backgroundLayer] setAnchorPoint:currentAnchor];
		}
	}
	else if( [keyPath isEqualToString:@"anchorY"] )
	{
		CSSprite *sprite = [modelObject_ selectedSprite];
		if(sprite)
		{
			CGPoint currentAnchor = [sprite anchorPoint];
			currentAnchor.y = [modelObject_ anchorY];
			[sprite setAnchorPoint:currentAnchor];
		}
		else
		{
			CGPoint currentAnchor = [[modelObject_ backgroundLayer] anchorPoint];
			currentAnchor.y = [modelObject_ anchorY];
			[[modelObject_ backgroundLayer] setAnchorPoint:currentAnchor];
		}		
	}
	else if( [keyPath isEqualToString:@"scaleX"] )
	{
		CSSprite *sprite = [modelObject_ selectedSprite];
		if(sprite)
		{
			[sprite setScaleX:[modelObject_ scaleX]];
		}
		else
		{
			[[modelObject_ backgroundLayer] setScaleX:[modelObject_ scaleX]];
		}
	}
	else if( [keyPath isEqualToString:@"scaleY"] )
	{
		CSSprite *sprite = [modelObject_ selectedSprite];
		if(sprite)
		{
			[sprite setScaleY:[modelObject_ scaleY]];
		}
		else
		{
			[[modelObject_ backgroundLayer] setScaleY:[modelObject_ scaleY]];
		}
	}	
	else if( [keyPath isEqualToString:@"flipX"] )
	{
		CSSprite *sprite = [modelObject_ selectedSprite];
		if(sprite)
		{
			NSInteger state = [modelObject_ flipX];
			if(state == NSOnState)
			{
				[sprite setFlipX:YES];
			}
			else
			{
				[sprite setFlipX:NO];
			}
		}
	}
	else if( [keyPath isEqualToString:@"flipY"] )
	{
		CSSprite *sprite = [modelObject_ selectedSprite];
		if(sprite)
		{
			NSInteger state = [modelObject_ flipY];
			if(state == NSOnState)
			{
				[sprite setFlipY:YES];
			}
			else
			{
				[sprite setFlipY:NO];
			}
		}
	}
	else if( [keyPath isEqualToString:@"opacity"] )
	{
		CSSprite *sprite = [modelObject_ selectedSprite];
		if(sprite)
		{
			[sprite setOpacity:[modelObject_ opacity]];
		}
		else 
		{
			[[modelObject_ backgroundLayer] setOpacity:[modelObject_ opacity]];
		}

	}
	else if( [keyPath isEqualToString:@"color"] )
	{
		// grab rgba values
		NSColor *color = [[modelObject_ color] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
		
		CGFloat r, g, b, a;			
		a = [color alphaComponent];
		r = [color redComponent] * a * 255;
		g = [color greenComponent] * a * 255;
		b = [color blueComponent] * a * 255;
		
		CSSprite *sprite = [modelObject_ selectedSprite];
		if(sprite)
		{
			[sprite setColor:ccc3(r, g, b)];
		}
		else
		{
			[[modelObject_ backgroundLayer] setColor:ccc3(r, g, b)];
		}
	}
	else if( [keyPath isEqualToString:@"relativeAnchor"] )
	{
		CSSprite *sprite = [modelObject_ selectedSprite];
		if(sprite)
		{
			NSInteger state = [modelObject_ relativeAnchor];
			if(state == NSOnState)
			{
				[sprite setIsRelativeAnchorPoint:YES];
			}
			else
			{
				[sprite setIsRelativeAnchorPoint:NO];
			}
		}
		else
		{
			NSInteger state = [modelObject_ relativeAnchor];
			if(state == NSOnState)
			{
				[[modelObject_ backgroundLayer] setIsRelativeAnchorPoint:YES];
			}
			else
			{
				[[modelObject_ backgroundLayer] setIsRelativeAnchorPoint:NO];
			}			
		}

	}
	else if( [keyPath isEqualToString:@"rotation"] )
	{
		CSSprite *sprite = [modelObject_ selectedSprite];
		if(sprite)
		{
			[sprite setRotation:[modelObject_ rotation]];
		}
		else
		{
			[[modelObject_ backgroundLayer] setRotation:[modelObject_ rotation]];
		}
	}
	else if( [keyPath isEqualToString:@"stageWidth"] )
	{
		CGSize s = [[CCDirector sharedDirector] winSize];
		s.width = modelObject_.stageWidth;
		[(CSMacGLView *)[[CCDirector sharedDirector] openGLView] setWorkspaceSize: s];
		[(CSMacGLView *)[[CCDirector sharedDirector] openGLView] updateWindow ];
		
		[self.mainLayer updateForScreenReshapeSafely: nil];
		
	}
	else if( [keyPath isEqualToString:@"stageHeight"] )
	{
		CGSize s = [[CCDirector sharedDirector] winSize];
		s.height = modelObject_.stageHeight;
		[(CSMacGLView *)[[CCDirector sharedDirector] openGLView] setWorkspaceSize: s];
		[(CSMacGLView *)[[CCDirector sharedDirector] openGLView] updateWindow ];
		
		[self.mainLayer updateForScreenReshapeSafely: nil];
	}
	
	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark Sprites

- (void) ensureUniqueNameForSprite: (CSSprite *) aSprite
{
	NSString *originalName = [aSprite name];
	NSString *name = [NSString stringWithString: originalName];
	NSUInteger i = 0;
	while( ([modelObject_ spriteWithName: name] != nil) && ([modelObject_ spriteWithName: name] != aSprite) )
	{
		NSAssert(i <= NSUIntegerMax, @"CSObjectController#ensureUniqueNameForSprite: Added too many of the same sprite");
		name = [originalName stringByAppendingFormat:@"_%u", i++];
	}
	aSprite.name = name;
}

- (NSArray *) allowedFileTypes
{
	return [NSArray arrayWithObjects:@"png", @"gif", @"jpg", @"jpeg", @"tif", @"tiff", @"bmp", @"ccz", @"pvr", nil];
}

- (NSArray *) allowedFilesWithFiles: (NSArray *) files
{
	if (!files)
		return nil;
	
	NSMutableArray *allowedFiles = [NSMutableArray arrayWithCapacity:[files count]];
	
	for (NSString *file in files)
	{
		if ( ![file isKindOfClass:[NSString class]] )
			continue;
		
		NSString *curFileExtension = [file pathExtension];
		
		for (NSString *fileType in [self allowedFileTypes] )
		{
			if ([fileType isEqualToString: curFileExtension])
			{
				[allowedFiles addObject:file];
				break;
			}
		}
	}
	
	return allowedFiles;
}

// adds sprites on cocos thread
// executes immediatly if curThread == cocosThread
- (void)addSpritesWithFilesSafely:(NSArray *)files
{
	NSThread *cocosThread = [[CCDirector sharedDirector] runningThread] ;
	
	[self performSelector:@selector(addSpritesWithFiles:)
				 onThread:cocosThread
			   withObject:files 
			waitUntilDone:([[NSThread currentThread] isEqualTo:cocosThread])];
}

// designated sprites adding method
- (void)addSpritesWithFiles:(NSArray *)files
{
	[[CCTextureCache sharedTextureCache] removeUnusedTextures];
	
	for(NSString *filename in files)
	{		
		// create key for the sprite
		NSString *originalName = [filename lastPathComponent];
		NSString *name = [NSString stringWithString:originalName];
		
		CSSprite *sprite = [CSSprite spriteWithFile:filename];
		[sprite setName:name];
		[sprite setFilename:filename];
		
		[self ensureUniqueNameForSprite: sprite];
		
		@synchronized( [modelObject_ spriteArray] )
		{
			[[modelObject_ spriteArray] addObject:sprite];
		}
		
		// notify view that we added the sprite
		[[NSNotificationCenter defaultCenter] postNotificationName:@"addedSprite" object:nil];
	}
	
	// reload the table
	[spriteTableView_ reloadData];
}

- (void)deleteAllSprites
{
	// Deselect everything.
	[modelObject_ setSelectedSprite:nil];
		
	// Remove all sprites from main layer.
    NSArray *spriteArray = [NSArray arrayWithArray:[modelObject_ spriteArray]];
    void (^removeAllSpritesBlock)() =
    ^{
        for (CCNode * sprite in spriteArray )
        {
            // Only remove child if we're the parent.
            if( [sprite parent] == mainLayer_ )
                [mainLayer_ removeChild:sprite cleanup:YES];
        }
    };
    
    // Remove all sprites from the dictionary.
    @synchronized([modelObject_ spriteArray])
    {
        [[modelObject_ spriteArray] removeAllObjects];
    }
    
    [mainLayer_ runAction: [CCCallBlock actionWithBlock: removeAllSpritesBlock] ];
}

- (void)deleteSprite:(CSSprite *)sprite
{
	if(sprite)
	{
        // Deselect sprite. 
        [modelObject_ setSelectedSprite:nil];
        [spriteTableView_ deselectAll:nil];
        [spriteTableView_ setDataSource: nil];
        
        
        // Run removeSprite block in Cocos2D Thread.
        void(^removeSprite)() =
        ^{
            // Only remove child if we're the parent.
            if( [sprite parent] == mainLayer_ )
                [mainLayer_ removeChild:sprite cleanup:YES];
            
            // Remove the sprite from the dictionary.
            @synchronized([modelObject_ spriteArray])
            {
                [[modelObject_ spriteArray] removeObject:sprite];
            }   
            
            [spriteTableView_ setDataSource: dataSource_];
        };
        [mainLayer_ runAction: [CCCallBlock actionWithBlock: removeSprite]];		
	}	
}

#pragma mark Notifications

- (void)spriteTableSelectionDidChange:(NSNotification *)aNotification
{
	NSInteger index = [spriteTableView_ selectedRow];
	if(index >= 0)
	{
		CSSprite *sprite = [[modelObject_ spriteArray] objectAtIndex:index];
		[modelObject_ setSelectedSprite:sprite];
	}
	else
	{
		[modelObject_ setSelectedSprite:nil];
	}

}

- (void) spriteTableSelectionDidRename: (NSNotification *) aNotification
{
	NSInteger index = [spriteTableView_ selectedRow];
	if(index >= 0)
	{
		CSSprite *sprite = [[modelObject_ spriteArray] objectAtIndex:index];
		[modelObject_ setSelectedSprite:sprite];
		[modelObject_ setName:[[aNotification userInfo] objectForKey:@"name"]];
		
	}
}

- (void) setInfoPanelView: (NSView *) aView
{
	//CGRect frame = [infoPanel_ frame];
	//frame.size = [aView frame].size;
	[infoPanel_ setContentView:aView];
	//[infoPanel_ setFrame: frame display: YES];
}

- (void)didChangeSelectedSprite:(NSNotification *)aNotification
{
	if( ![modelObject_ selectedSprite] )
	{
		// Editing Background
		[self setInfoPanelView: self.backgroundInfoView];
		[spriteTableView_ deselectAll:nil];
	}
	else
	{
		// Editing Selected Sprite 
		[self setInfoPanelView: self.spriteInfoView];
		
		// get the index for the sprite
		CSSprite *sprite = [modelObject_ selectedSprite];
		if(sprite)
		{
			NSArray *array = [modelObject_ spriteArray];
			NSIndexSet *set = [NSIndexSet indexSetWithIndex:[array indexOfObject:sprite]];
			[spriteTableView_ selectRowIndexes:set byExtendingSelection:NO];
		}
	}
}

#pragma mark Save / Load

- (NSDictionary *)dictionaryFromLayerForBaseDirPath: (NSString *) baseDirPath
{
	CCLayerColor *bgLayer = [modelObject_ backgroundLayer];
	
	NSMutableDictionary *bg = [NSMutableDictionary dictionaryWithCapacity:15];
	[bg setValue:[NSNumber numberWithFloat:[bgLayer contentSize].width] forKey:@"stageWidth"];
	[bg setValue:[NSNumber numberWithFloat:[bgLayer contentSize].height] forKey:@"stageHeight"];
	[bg setValue:[NSNumber numberWithFloat:[bgLayer position].x] forKey:@"posX"];
	[bg setValue:[NSNumber numberWithFloat:[bgLayer position].y] forKey:@"posY"];
	[bg setValue:[NSNumber numberWithInteger:[bgLayer zOrder]] forKey:@"posZ"];
	[bg setValue:[NSNumber numberWithFloat:[bgLayer anchorPoint].x] forKey:@"anchorX"];
	[bg setValue:[NSNumber numberWithFloat:[bgLayer anchorPoint].y] forKey:@"anchorY"];
	[bg setValue:[NSNumber numberWithFloat:[bgLayer scaleX]] forKey:@"scaleX"];
	[bg setValue:[NSNumber numberWithFloat:[bgLayer scaleY]] forKey:@"scaleY"];
	[bg setValue:[NSNumber numberWithFloat:[bgLayer opacity]] forKey:@"opacity"];
	[bg setValue:[NSNumber numberWithFloat:[bgLayer color].r] forKey:@"colorR"];
	[bg setValue:[NSNumber numberWithFloat:[bgLayer color].g] forKey:@"colorG"];
	[bg setValue:[NSNumber numberWithFloat:[bgLayer color].b] forKey:@"colorB"];
	[bg setValue:[NSNumber numberWithFloat:[bgLayer rotation]] forKey:@"rotation"];
	[bg setValue:[NSNumber numberWithBool:[bgLayer isRelativeAnchorPoint]] forKey:@"relativeAnchor"];
	
	NSMutableArray *children = [NSMutableArray arrayWithCapacity:[[mainLayer_ children] count]];
	CCNode *child;
	CCARRAY_FOREACH([mainLayer_ children], child)
	{
		if( [child isKindOfClass:[CSSprite class]] )
		{
			CSSprite *sprite = (CSSprite *)child;
			[self ensureUniqueNameForSprite: sprite];
			
			// Use relative path if needed
			if ([[sprite filename] isAbsolutePath])
			{
				// Use relative path if possible
				NSString *relativePath = [[sprite filename] relativePathFromBaseDirPath: baseDirPath ];
				if (relativePath)
					sprite.filename = relativePath;		
			}
			
			// Get Sprite Dictionary Representation & Save it to children array
			NSDictionary *childValues = [sprite dictionaryRepresentation];			
			[children addObject:childValues];
		}
	}
	
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
	[dict setValue:bg forKey:@"background"];
	[dict setValue:children forKey:@"children"];
	
	return [NSDictionary dictionaryWithDictionary:dict];
}

- (void)saveProjectToFile:(NSString *)filename
{
	NSDictionary *dict = [self dictionaryFromLayerForBaseDirPath:[filename stringByDeletingLastPathComponent]];
	[dict writeToFile:filename atomically:YES];
	
	// Rembember filename for fast save next time.
	self.projectFilename = filename;
}

#pragma mark IBActions - Windows

- (IBAction)openInfoPanel:(id)sender
{
	[infoPanel_ makeKeyAndOrderFront:nil];
	[infoPanel_ setLevel:[[[[CCDirector sharedDirector] openGLView] window] level]+1];
}

- (IBAction) openSpritesPanel: (id) sender
{
	[spritesPanel_ makeKeyAndOrderFront: nil];
	[spritesPanel_ setLevel:[[[[CCDirector sharedDirector] openGLView] window] level]+1];
}

- (IBAction)openMainWindow:(id)sender
{
	[[[[CCDirector sharedDirector] openGLView] window] makeKeyAndOrderFront:nil];
	[infoPanel_ setLevel:NSNormalWindowLevel];
	[spritesPanel_ setLevel:NSNormalWindowLevel];
}

#pragma mark IBActions - Save/Load

// if we're opened a file - we can revert to saved and save without save as
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	DebugLog(@"fuck");
	
	// "Save"
	if ([menuItem action] == @selector(saveProject:))
		return YES;
	
	// "Revert to Saved"
	if ([menuItem action] == @selector(saveProject:))
	{
		if (self.projectFilename)
			return YES;
		return NO;
	}
	
	// "Cut"
	if ([menuItem action] == @selector(cutMenuItemPressed:))
	{
		if ([modelObject_ selectedSprite])
			return YES;
		return NO;
	}
	
	// "Copy"
	if ([menuItem action] == @selector(copyMenuItemPressed:))
	{
		if ([modelObject_ selectedSprite])
			return YES;
		return NO;
	}
	
	// "Paste"
	if ([menuItem action] == @selector(pasteMenuItemPressed:))
	{
		NSPasteboard *generalPasteboard = [NSPasteboard generalPasteboard];
        NSDictionary *options = [NSDictionary dictionary];
        return [generalPasteboard canReadObjectForClasses:[NSArray arrayWithObject:[CSSprite class]] options:options];
	}
	
	// "Delete"
	if ([menuItem action] == @selector(deleteMenuItemPressed:))
	{
		if ([modelObject_ selectedSprite])
			return YES;
		return NO;
	}
	
	// "Show Borders"- using ivar, because NSOnState doesn't set right in IB
	showBordersMenuItem_.state = (mainLayer_.showBorders) ? NSOnState : NSOffState;
	
	return YES;
}

- (IBAction)saveProject:(id)sender
{
	if (! self.projectFilename) 
	{
		[self saveProjectAs: sender];
		return;
	}
	
	[self saveProjectToFile:self.projectFilename];
}


- (IBAction)saveProjectAs:(id)sender
{	
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel setCanCreateDirectories:YES];
	[savePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"csd", @"ccb", nil]];
	
	// handle the save panel
	[savePanel beginSheetModalForWindow:[[[CCDirector sharedDirector] openGLView] window] completionHandler:^(NSInteger result) {
		if(result == NSOKButton)
		{
			NSString *file = [savePanel filename];
			[self saveProjectToFile:file];
		}
	}];
}
- (IBAction)newProject:(id)sender
{
	// remove all sprites
	[self deleteAllSprites];
	
	// reset background
	modelObject_.color = [NSColor colorWithDeviceRed:0 green:0 blue:0 alpha:0];
	modelObject_.opacity = 0;
	modelObject_.stageWidth = 480;
	modelObject_.stageHeight = 320;
	
	// reset filename
	self.projectFilename = nil;
	
	// reload the table
	[spriteTableView_ reloadData];
	
}

- (IBAction)openProject:(id)sender
{
	// initialize panel + set flags
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:YES];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setAllowedFileTypes:[NSArray arrayWithObject:@"csd"]];
	[openPanel setAllowsOtherFileTypes:NO];	
	
	// handle the open panel
	[openPanel beginSheetModalForWindow:[[[CCDirector sharedDirector] openGLView] window] completionHandler:^(NSInteger result) {
		if(result == NSOKButton)
		{
			NSArray *files = [openPanel filenames];
			NSString *file = [files objectAtIndex:0];
			NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:file];
			
			if(dict)
			{
				[mainLayer_ loadProjectFromDictionarySafely:dict];
				self.projectFilename = file;
			}
		}
	}];
}

- (IBAction)revertToSavedProject:(id)sender
{
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:self.projectFilename];
	[mainLayer_ loadProjectFromDictionarySafely:dict];
}

#pragma mark IBActions - Sprites

- (IBAction)addSprite:(id)sender
{
	// allowed file types
	NSArray *allowedTypes = [self allowedFileTypes];
	
	// initialize panel + set flags
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:YES];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setAllowedFileTypes:allowedTypes];
	[openPanel setAllowsOtherFileTypes:NO];
	
	// handle the open panel
	[openPanel beginSheetModalForWindow:[[[CCDirector sharedDirector] openGLView] window] completionHandler:^(NSInteger result) {
		if(result == NSOKButton)
		{
			NSArray *files = [openPanel filenames];
			
			[self addSpritesWithFilesSafely: files];
		}
	}];
}

- (IBAction)spriteAddButtonClicked:(id)sender
{
	[self addSprite:sender];
}

- (IBAction)spriteDeleteButtonClicked:(id)sender
{
	NSInteger index =  [spriteTableView_ selectedRow];
	NSArray *values = [modelObject_ spriteArray];
	
	if ( values && (index >= 0) && (index < [values count]) )
	{
		CSSprite *sprite = [values objectAtIndex:index];
		[self deleteSprite:sprite];
	}
}

#pragma mark IBActions - Zoom

- (IBAction)resetZoom:(id)sender
{
	[(CSMacGLView *)[[CCDirector sharedDirector] openGLView] resetZoom];
}

#pragma mark IBActions - Menus
- (IBAction) showBordersMenuItemPressed: (id) sender
{
	mainLayer_.showBorders = ([sender state] == NSOffState);
}

- (IBAction) deleteMenuItemPressed: (id) sender
{
	[self deleteSprite:[modelObject_ selectedSprite]];
}

- (IBAction) cutMenuItemPressed: (id) sender
{
	[self copyMenuItemPressed: sender];
	[self deleteSprite:[modelObject_ selectedSprite]];
}

- (IBAction) copyMenuItemPressed: (id) sender
{
	// write selected sprite to pasteboard
	NSArray *objectsToCopy = [modelObject_ selectedSprites];
	if (objectsToCopy)
	{
		NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
		[pasteboard clearContents];		
		
		if (![pasteboard writeObjects:objectsToCopy] )
		{
			DebugLog(@"Error writing to pasteboard, sprites = %@", objectsToCopy);
		}
	}
}

- (void)addSpritesWithArray:(NSArray *)sprites
{
	[[CCTextureCache sharedTextureCache] removeUnusedTextures];
	
	for(CSSprite *sprite in sprites)
	{
		[self ensureUniqueNameForSprite: sprite];
		@synchronized( [modelObject_ spriteArray] )
		{			
			[[modelObject_ spriteArray] addObject:sprite];
		}
		
		// notify view that we added the sprite
		[[NSNotificationCenter defaultCenter] postNotificationName:@"addedSprite" object:nil];
	}
	
	// reload the table
	[spriteTableView_ reloadData];
}

- (IBAction) pasteMenuItemPressed: (id) sender
{    
    NSPasteboard *generalPasteboard = [NSPasteboard generalPasteboard];
    NSDictionary *options = [NSDictionary dictionary];
    
    NSArray *newSprites = [generalPasteboard readObjectsForClasses:[NSArray arrayWithObject:[CSSprite class]] options:options];
    
	[self addSpritesWithArray: newSprites];
}


@end
