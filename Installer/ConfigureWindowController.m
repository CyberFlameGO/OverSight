//
//  ConfigureWindowController.m
//  OverSight
//
//  Created by Patrick Wardle on 9/01/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Configure.h"
#import "Utilities.h"
#import "ConfigureWindowController.h"

@implementation ConfigureWindowController

@synthesize statusMsg;
@synthesize moreInfoButton;

//automatically called when nib is loaded
// ->just center window
-(void)awakeFromNib
{
    //center
    [self.window center];

    return;
}

//configure window/buttons
// ->also brings window to front
-(void)configure:(BOOL)isInstalled
{
    //set window title
    [self window].title = [NSString stringWithFormat:@"version %@", getAppVersion()];
    
    //yosemite doesn't support emojis :P
    if(getVersion(gestaltSystemVersionMinor) <= OS_MINOR_VERSION_YOSEMITE)
    {
        //init status msg
        [self.statusMsg setStringValue:@"monitor audio & video access"];
    }
    //el capitan supports emojis
    else
    {
        //init status msg
        [self.statusMsg setStringValue:@"monitor 🎤 and 📸 access"];
    }
    
    //enable 'uninstall' button when app is installed already
    if(YES == isInstalled)
    {
        //enable
        self.uninstallButton.enabled = YES;
    }
    //otherwise disable
    else
    {
        //disable
        self.uninstallButton.enabled = NO;
    }
    
    //make 'install' have focus
    // ->more likely they'll be upgrading, but do after a delay so it sticks...
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        //set responder
       [self.window makeFirstResponder:self.installButton];
        
    });

    //set delegate
    [self.window setDelegate:self];

    return;
}

//display (show) window
// ->center, make front, set bg to white, etc
-(void)display
{
    //center window
    [[self window] center];
    
    //show (now configured) windows
    [self showWindow:self];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];

    return;
}

//button handler for uninstall/install
-(IBAction)buttonHandler:(id)sender
{
    //button title
    NSString* buttonTitle = nil;
    
    //extact button title
    buttonTitle = ((NSButton*)sender).title;
    
    //action
    NSUInteger action = 0;
    
    //hide 'get more info' button
    self.moreInfoButton.hidden = YES;
    
    //set action
    // ->install daemon
    if(YES == [buttonTitle isEqualToString:ACTION_INSTALL])
    {
        //set
        action = ACTION_INSTALL_FLAG;
    }
    //set action
    // ->uninstall daemon
    else
    {
        //set
        action = ACTION_UNINSTALL_FLAG;
    }
    
    //disable 'x' button
    // ->don't want user killing app during install/upgrade
    [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:NO];
    
    //clear status msg
    [self.statusMsg setStringValue:@""];
    
    //force redraw of status msg
    // ->sometime doesn't refresh (e.g. slow VM)
    [self.statusMsg setNeedsDisplay:YES];
    
    //invoke logic to install/uninstall
    // ->do in background so UI doesn't block
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        //install/uninstall
        [self lifeCycleEvent:action];
    
    });

//bail
bail:
    
    return;
}

//button handler for '?' button (on an error)
// ->load objective-see's documentation for error(s) in default browser
-(IBAction)info:(id)sender
{
    //url
    NSURL *helpURL = nil;
    
    //build help URL
    helpURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@#errors", PRODUCT_URL]];
    
    //open URL
    // ->invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:helpURL];
    
    return;
}

//perform install | uninstall via Control obj
// ->invoked on background thread so that UI doesn't block
-(void)lifeCycleEvent:(NSUInteger)event
{
    //status var
    BOOL status = NO;
    
    //configure object
    Configure* configureObj = nil;
    
    //dbg msg
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"handling life cycle event, %lu", (unsigned long)event]);
    
    //alloc control object
    configureObj = [[Configure alloc] init];
    
    //begin event
    // ->updates ui on main thread
    dispatch_sync(dispatch_get_main_queue(),
    ^{
        //complete
        [self beginEvent:event];
    });
    
    //sleep
    // ->allow 'install' || 'uninstall' msg to show up
    sleep(1);
    
    //perform action (install | uninstall)
    // ->perform background actions
    if(YES == [configureObj configure:event])
    {
        //set flag
        status = YES;
    }
    
    //error occurred
    else
    {
        //err msg
        //logMsg(LOG_ERR, @"ERROR: failed to perform life cycle event");
        
        //set flag
        status = NO;
    }
    
    //complet event
    // ->updates ui on main thread
    dispatch_async(dispatch_get_main_queue(),
    ^{
        //complete
        [self completeEvent:status event:event];
    });
    
    return;
}

//begin event
// ->basically just update UI
-(void)beginEvent:(NSUInteger)event
{
    //align text left
    [self.statusMsg setAlignment:NSLeftTextAlignment];
    
    //install msg
    if(ACTION_INSTALL_FLAG == event)
    {
        //update status msg
        // ->with space to avoid spinner
        [self.statusMsg setStringValue:@"\t  Installing..."];
    }
    //uninstall msg
    else
    {
        //update status msg
        // ->with space to avoid spinner
        [self.statusMsg setStringValue:@"\t  Uninstalling..."];
    }
    
    //disable action button
    self.uninstallButton.enabled = NO;
    
    //disable cancel button
    self.installButton.enabled = NO;
    
    //show spinner
    [self.activityIndicator setHidden:NO];
    
    //start spinner
    [self.activityIndicator startAnimation:nil];
    
    return;
}

//complete event
// ->update UI after background event has finished
-(void)completeEvent:(BOOL)success event:(NSUInteger)event
{
    //action
    NSString* action = nil;
    
    //result msg
    NSMutableString* resultMsg = nil;
    
    //msg font
    NSColor* resultMsgColor = nil;
    
    //generally want centered text
    [self.statusMsg setAlignment:NSCenterTextAlignment];
    
    //set action msg for install
    if(ACTION_INSTALL_FLAG == event)
    {
        //set msg
        action = @"install";
    }
    //set action msg for uninstall
    else
    {
        //set msg
        action = @"uninstall";
    }
    
    //success
    if(YES == success)
    {
        //set result msg
        resultMsg = [NSMutableString stringWithFormat:@"OverSight %@ed!", action];
        
        //add extra info when installed
        if(ACTION_INSTALL_FLAG == event)
        {
            //append
            [resultMsg appendString:@"\nconfig via ☔️ in status bar"];
        }
        
        //set font to black
        resultMsgColor = [NSColor blackColor];
    }
    //failure
    else
    {
        //set result msg
        resultMsg = [NSMutableString stringWithFormat:@"error: %@ failed", action];
        
        //set font to red
        resultMsgColor = [NSColor redColor];
        
        //show 'get more info' button
        self.moreInfoButton.hidden = NO;
    }
    
    //stop/hide spinner
    [self.activityIndicator stopAnimation:nil];
    
    //hide spinner
    [self.activityIndicator setHidden:YES];
    
    //set font to bold
    [self.statusMsg setFont:[NSFont fontWithName:@"Menlo-Bold" size:13]];
    
    //set msg color
    [self.statusMsg setTextColor:resultMsgColor];
    
    //set status msg
    [self.statusMsg setStringValue:resultMsg];
    
    //toggle buttons
    // ->after install turn on 'uninstall' and off 'install'
    if(ACTION_INSTALL_FLAG == event)
    {
        //enable uninstall
        self.uninstallButton.enabled = YES;
        
        //disable install
        self.installButton.enabled = NO;
    }
    //toggle buttons
    // ->after uninstall turn off 'uninstall' and on 'install'
    else
    {
        //disable
        self.uninstallButton.enabled = NO;
        
        //enable close button
        self.installButton.enabled = YES;
    }

    //ok to re-enable 'x' button
    [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:YES];
    
    //(re)make window window key
    [self.window makeKeyAndOrderFront:self];
    
    //(re)make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//automatically invoked when window is closing
// ->just exit application
-(void)windowWillClose:(NSNotification *)notification
{
    //exit
    [NSApp terminate:self];
    
    return;
}


@end
