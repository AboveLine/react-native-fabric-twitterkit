//
//  FabricTwitterKit.m
//  FabricTwitterKit
//
//  Created by Trevor Porter on 8/1/16.
//  Copyright © 2016 Trevor Porter. All rights reserved.
//
//  Modifications:
//  Copyright (C) 2016 Sony Interactive Entertainment Inc.
//  Licensed under the MIT License. See the LICENSE file in the project root for license information.

#import "FabricTwitterKit.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTBridge.h>
//#import <Crashlytics/Crashlytics.h>

@implementation FabricTwitterKit {
    RCTPromiseResolveBlock composeTweetResolve;
    RCTPromiseRejectBlock composeTweetReject;
}
@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(init:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  )
{
    [[Twitter sharedInstance] startWithConsumerKey:options[@"consumerKey"] consumerSecret:options[@"consumerSecret"]];
}

RCT_EXPORT_METHOD(loginWithCreds:(NSDictionary *)creds
                  :(RCTPromiseResolveBlock)resolve
                  :(RCTPromiseRejectBlock)reject
                  )
{
    NSString *authToken = creds[@"authToken"];
    NSString *authTokenSecret = creds[@"authTokenSecret"];
    TWTRSessionStore *store = [[Twitter sharedInstance] sessionStore];
    [store saveSessionWithAuthToken:authToken authTokenSecret:authTokenSecret completion:^(TWTRSession *session, NSError *error) {
        if (session) {
            NSDictionary *body = @{@"authToken": session.authToken,
                                   @"authTokenSecret": session.authTokenSecret,
                                   @"userID":session.userID,
                                   @"userName":session.userName};
            resolve(body);
        } else {
            NSLog(@"error: %@", [error localizedDescription]);
            reject(@"error", @"twitter kit loginWithCreds failed", error);
        }
    }];
}

RCT_EXPORT_METHOD(login:(RCTResponseSenderBlock)callback)
{
    [[Twitter sharedInstance] logInWithCompletion:^(TWTRSession *session, NSError *error) {
        if (session) {
            NSDictionary *body = @{@"authToken": session.authToken,
                                   @"authTokenSecret": session.authTokenSecret,
                                   @"userID":session.userID,
                                   @"userName":session.userName};
            callback(@[[NSNull null], body]);
        } else {
            NSLog(@"error: %@", [error localizedDescription]);
            callback(@[[error localizedDescription]]);
        }
    }];
}

RCT_EXPORT_METHOD(fetchProfile:(RCTResponseSenderBlock)callback)
{
    TWTRAPIClient *client = [[TWTRAPIClient alloc] init];
    TWTRSessionStore *store = [[Twitter sharedInstance] sessionStore];

    TWTRSession *lastSession = store.session;

    if(lastSession) {
        NSString *showEndpoint = @"https://api.twitter.com/1.1/users/show.json";
        NSDictionary *params = @{@"user_id": lastSession.userID};

        NSError *clientError;
        NSURLRequest *request = [client
                                 URLRequestWithMethod:@"GET"
                                 URL:showEndpoint
                                 parameters:params
                                 error:&clientError];

          if (request) {
            [client
             sendTwitterRequest:request
             completion:^(NSURLResponse *response,
                          NSData *data,
                          NSError *connectionError) {
                 if (data) {
                     // handle the response data e.g.
                     NSError *jsonError;
                     NSDictionary *json = [NSJSONSerialization
                                           JSONObjectWithData:data
                                           options:0
                                           error:&jsonError];
                     NSLog(@"%@",[json description]);
                     callback(@[[NSNull null], json]);
                 }
                 else {
                     NSLog(@"Error code: %ld | Error description: %@", (long)[connectionError code], [connectionError localizedDescription]);
                     callback(@[[connectionError localizedDescription]]);
                 }
             }];
        }
        else {
            NSLog(@"Error: %@", clientError);
        }

    }
    else {
      callback(@[@"Session must not be null."]);
    }

}

RCT_EXPORT_METHOD(fetchTweet:(NSDictionary *)options :(RCTResponseSenderBlock)callback)
{
    TWTRAPIClient *client = [[TWTRAPIClient alloc] init];
    TWTRSessionStore *store = [[Twitter sharedInstance] sessionStore];
    NSString *id = options[@"id"];
    NSString *trim_user = options[@"trim_user"];
    NSString *include_my_retweet = options[@"include_my_retweet"];

    TWTRSession *lastSession = store.session;

    if(lastSession) {
        NSString *showEndpoint = @"https://api.twitter.com/1.1/statuses/show.json";
        NSDictionary *params = @{
                                    @"id": id,
                                    @"trim_user": trim_user,
                                    @"include_my_retweet": include_my_retweet
                                };

        NSError *clientError;
        NSURLRequest *request = [client
                                 URLRequestWithMethod:@"GET"
                                 URL:showEndpoint
                                 parameters:params
                                 error:&clientError];

        if (request) {
            [client
             sendTwitterRequest:request
             completion:^(NSURLResponse *response,
                          NSData *data,
                          NSError *connectionError) {
                 if (data) {
                     // handle the response data e.g.
                     NSError *jsonError;
                     NSDictionary *json = [NSJSONSerialization
                                           JSONObjectWithData:data
                                           options:0
                                           error:&jsonError];
                     NSLog(@"%@",[json description]);
                     callback(@[[NSNull null], json]);
                 }
                 else {
                     NSLog(@"Error code: %ld | Error description: %@", (long)[connectionError code], [connectionError localizedDescription]);
                     callback(@[[connectionError localizedDescription]]);
                 }
             }];
        }
        else {
            NSLog(@"Error: %@", clientError);
        }

    }
    else {
      callback(@[@"Session must not be null."]);
    }

}

RCT_EXPORT_METHOD(composeTweet:(NSDictionary *)options
                  :(RCTPromiseResolveBlock)resolve
                  :(RCTPromiseRejectBlock)reject
                  )
{
    NSString *setText = options[@"setText"];
    NSString *setURL = options[@"setURL"];
    NSString *setImage = options[@"setImage"];

    NSString *composedText = [NSString stringWithFormat:@"%@ %@", setText, setURL];

    UIViewController *rootView = [UIApplication sharedApplication].keyWindow.rootViewController;

    if ([[Twitter sharedInstance].sessionStore hasLoggedInUsers]) {
        TWTRComposerViewController *composer = [[TWTRComposerViewController alloc]
                                                initWithInitialText:composedText
                                                image:[UIImage imageNamed:setImage]
                                                videoURL:nil];
        composer.delegate = self;
        self->composeTweetResolve = resolve;
        self->composeTweetReject = reject;
        [rootView presentViewController:composer animated:YES completion:nil];
    } else {
        reject(@"error", @"TwitterKit: A user must already be logged into TwitterKit before composing a tweet.", nil);
    }
}

RCT_EXPORT_METHOD(logOut
                  :(RCTPromiseResolveBlock)resolve
                  :(RCTPromiseRejectBlock)reject
                  )
{
    TWTRSessionStore *store = [[Twitter sharedInstance] sessionStore];
    NSString *userID = store.session.userID;

    [store logOutUserID:userID];
}


- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

- (void)composerDidCancel:(TWTRComposerViewController *)controller
{
    self->composeTweetResolve(@false);
}

- (void)composerDidFail:(TWTRComposerViewController *)controller withError:(NSError *)error
{
    UIViewController *rootView = [UIApplication sharedApplication].keyWindow.rootViewController;
    [rootView dismissViewControllerAnimated:YES completion:nil];
    self->composeTweetReject(@"error", @"TwitterKit: composerDidFail", error);
}

- (void)composerDidSucceed:(TWTRComposerViewController *)controller withTweet:(TWTRTweet *)tweet
{
    NSDictionary *result = @{@"tweetID": tweet.tweetID,
                             @"text": tweet.text};
    self->composeTweetResolve(result);
}

@end
